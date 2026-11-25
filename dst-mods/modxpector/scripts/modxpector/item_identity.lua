-- Read-only, fail-closed snapshots of client-visible item identity.
-- This module never mutates entities, inventories, containers, or stack sizes.
local M = {}
local MAX_COLLECTION_ENTRIES = 512

local function safe_call(protected_call, fn, ...)
    if type(protected_call) ~= "function" or type(fn) ~= "function" then
        return false, nil
    end
    return protected_call(fn, ...)
end

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_entity(entity, protected_call)
    if entity == nil or type(entity.IsValid) ~= "function" then
        return false, "entity validity API unavailable"
    end
    local ok, valid = safe_call(protected_call, entity.IsValid, entity)
    if not ok or valid ~= true then
        return false, "entity is invalid or validity check failed"
    end
    return true
end

local function stack_size(entity, protected_call)
    local replica = entity.replica
    local stackable = type(replica) == "table" and replica.stackable or nil
    if stackable == nil then
        return 1, "not-replicated"
    end
    if type(stackable.StackSize) ~= "function" then
        return nil, "stack size API unavailable"
    end
    local ok, value = safe_call(protected_call, stackable.StackSize, stackable)
    if not ok or not finite_number(value) or value < 1 or value ~= math.floor(value) then
        return nil, "stack size is invalid"
    end
    return value, "replicated"
end

local function new_snapshot(kind)
    return {
        schema = "modxpector/item-identity-snapshot/v1",
        kind = kind,
        complete = true,
        items = {},
        by_guid = {},
        errors = {},
        item_count = 0,
    }
end

local function fail(snapshot, message)
    snapshot.complete = false
    snapshot.errors[#snapshot.errors + 1] = message
end

local function append_item(snapshot, entity, source, slot, protected_call)
    local valid, reason = valid_entity(entity, protected_call)
    if not valid then
        fail(snapshot, source .. ": " .. reason)
        return
    end

    local guid = entity.GUID
    if not finite_number(guid) or guid < 1 or guid ~= math.floor(guid) then
        fail(snapshot, source .. ": entity GUID is unavailable or invalid")
        return
    end
    if type(entity.prefab) ~= "string" or entity.prefab == "" then
        fail(snapshot, source .. ": entity prefab is unavailable")
        return
    end

    local size, size_source = stack_size(entity, protected_call)
    if size == nil then
        fail(snapshot, source .. ": " .. size_source)
        return
    end
    if snapshot.by_guid[guid] ~= nil then
        fail(snapshot, source .. ": duplicate GUID " .. tostring(guid))
        return
    end

    local item = {
        guid = guid,
        prefab = entity.prefab,
        stack_size = size,
        stack_size_source = size_source,
        source = source,
        slot = slot,
        entity = entity,
    }
    snapshot.items[#snapshot.items + 1] = item
    snapshot.by_guid[guid] = item
    snapshot.item_count = snapshot.item_count + 1
end

local function append_collection(snapshot, collection, source, protected_call)
    if type(collection) ~= "table" then
        fail(snapshot, source .. ": item collection is unavailable")
        return
    end
    local visited = 0
    for slot, entity in pairs(collection) do
        visited = visited + 1
        if visited > MAX_COLLECTION_ENTRIES then
            fail(snapshot, source .. ": collection exceeds the 512-entry safety limit")
            break
        end
        if entity ~= nil then
            append_item(snapshot, entity, source, slot, protected_call)
        end
    end
end

local function capture_inventory(inventory, protected_call)
    local snapshot = new_snapshot("player_inventory")
    if type(inventory) ~= "table" then
        fail(snapshot, "inventory replica unavailable")
        return snapshot
    end

    if type(inventory.GetItems) ~= "function" then
        fail(snapshot, "inventory GetItems API unavailable")
    else
        local ok, items = safe_call(protected_call, inventory.GetItems, inventory)
        if not ok then fail(snapshot, "inventory GetItems call failed")
        else append_collection(snapshot, items, "inventory_slot", protected_call) end
    end

    if type(inventory.GetEquips) ~= "function" then
        fail(snapshot, "inventory GetEquips API unavailable")
    else
        local ok, equips = safe_call(protected_call, inventory.GetEquips, inventory)
        if not ok then fail(snapshot, "inventory GetEquips call failed")
        else append_collection(snapshot, equips, "equipment_slot", protected_call) end
    end

    if type(inventory.GetActiveItem) ~= "function" then
        fail(snapshot, "inventory GetActiveItem API unavailable")
    else
        local ok, item = safe_call(protected_call, inventory.GetActiveItem, inventory)
        if not ok then fail(snapshot, "inventory GetActiveItem call failed")
        elseif item ~= nil then append_item(snapshot, item, "active_item", "active", protected_call) end
    end

    if type(inventory.GetOverflowContainer) ~= "function" then
        fail(snapshot, "inventory GetOverflowContainer API unavailable")
    else
        local ok, overflow = safe_call(protected_call, inventory.GetOverflowContainer, inventory)
        if not ok then
            fail(snapshot, "inventory GetOverflowContainer call failed")
        elseif overflow ~= nil then
            if type(overflow.GetItems) ~= "function" then
                fail(snapshot, "overflow container GetItems API unavailable")
            else
                local items_ok, items = safe_call(protected_call, overflow.GetItems, overflow)
                if not items_ok then fail(snapshot, "overflow container GetItems call failed")
                else append_collection(snapshot, items, "overflow_slot", protected_call) end
            end
        end
    end

    table.sort(snapshot.items, function(a, b)
        if a.source ~= b.source then return a.source < b.source end
        local a_slot, b_slot = tostring(a.slot), tostring(b.slot)
        if a_slot ~= b_slot then return a_slot < b_slot end
        return a.guid < b.guid
    end)
    return snapshot
end

local function capture_target(target, player, protected_call)
    local snapshot = new_snapshot("target_container")
    local valid, reason = valid_entity(target, protected_call)
    if not valid then
        fail(snapshot, "target: " .. reason)
        return snapshot
    end

    local container = target.replica ~= nil and target.replica.container or nil
    if type(container) ~= "table" then
        fail(snapshot, "target container replica unavailable")
        return snapshot
    end
    if type(container.IsOpenedBy) ~= "function" then
        fail(snapshot, "target container open-state API unavailable")
        return snapshot
    end
    local open_ok, is_open = safe_call(protected_call, container.IsOpenedBy, container, player)
    if not open_ok or is_open ~= true then
        fail(snapshot, "target container is not confirmed open by the player")
        return snapshot
    end
    if type(container.GetItems) ~= "function" then
        fail(snapshot, "target container GetItems API unavailable")
        return snapshot
    end
    local items_ok, items = safe_call(protected_call, container.GetItems, container)
    if not items_ok then
        fail(snapshot, "target container GetItems call failed")
    else
        append_collection(snapshot, items, "container_slot", protected_call)
    end

    table.sort(snapshot.items, function(a, b)
        local a_slot, b_slot = tostring(a.slot), tostring(b.slot)
        if a_slot ~= b_slot then return a_slot < b_slot end
        return a.guid < b.guid
    end)
    return snapshot
end

function M.Capture(inventory, player, target, protected_call)
    local result = {
        schema = "modxpector/item-identity-capture/v1",
        complete = false,
        player = capture_inventory(inventory, protected_call),
        target = target ~= nil and capture_target(target, player, protected_call) or nil,
    }
    result.complete = result.player.complete
        and (result.target == nil or result.target.complete)
    return result
end

local function inconclusive(reason)
    return {
        outcome = "inconclusive",
        reason = reason,
    }
end

function M.CompareExactMove(before, after, selected_guid, protected_call)
    if type(before) ~= "table" or before.schema ~= "modxpector/item-identity-capture/v1"
        or type(after) ~= "table" or after.schema ~= "modxpector/item-identity-capture/v1" then
        return inconclusive("snapshot schema is unavailable or unsupported")
    end
    if before.complete ~= true or after.complete ~= true
        or type(before.player) ~= "table" or before.player.complete ~= true
        or type(after.player) ~= "table" or after.player.complete ~= true
        or type(before.target) ~= "table" or before.target.complete ~= true
        or type(after.target) ~= "table" or after.target.complete ~= true
        or type(before.player.by_guid) ~= "table" or type(after.player.by_guid) ~= "table"
        or type(before.target.by_guid) ~= "table" or type(after.target.by_guid) ~= "table" then
        return inconclusive("one or more snapshots are incomplete or malformed")
    end
    if not finite_number(selected_guid) or selected_guid < 1
        or selected_guid ~= math.floor(selected_guid) then
        return inconclusive("selected item GUID is invalid")
    end

    local source_item = before.player.by_guid[selected_guid]
    if source_item == nil then
        return inconclusive("selected item was not present in the baseline player inventory")
    end
    if source_item.source ~= "inventory_slot" then
        return inconclusive("only items from normal inventory slots are supported")
    end
    if before.target.by_guid[selected_guid] ~= nil then
        return inconclusive("selected item already appeared in the target baseline")
    end

    local received_item = after.target.by_guid[selected_guid]
    if received_item == nil then
        return inconclusive("the same GUID was not observed in the target after the action")
    end
    if after.player.by_guid[selected_guid] ~= nil then
        return inconclusive("selected item is still present in the player snapshot")
    end
    if received_item.source ~= "container_slot" then
        return inconclusive("received item was not observed in a normal target container slot")
    end
    if received_item.entity ~= source_item.entity then
        return inconclusive("GUID matched but the local entity reference changed")
    end
    local source_valid = valid_entity(source_item.entity, protected_call)
    local received_valid = valid_entity(received_item.entity, protected_call)
    if source_valid ~= true or received_valid ~= true then
        return inconclusive("the captured item entity is no longer valid")
    end
    if received_item.prefab ~= source_item.prefab then
        return inconclusive("item prefab changed during the observed move")
    end
    if received_item.stack_size ~= source_item.stack_size
        or received_item.stack_size_source ~= source_item.stack_size_source then
        return inconclusive("stack quantity evidence changed or is not comparable")
    end

    return {
        outcome = "matched_candidate",
        reason = "same entity reference and GUID moved from a normal player slot to a normal target slot",
        guid = selected_guid,
        prefab = source_item.prefab,
        stack_size = source_item.stack_size,
        before_slot = source_item.slot,
        after_slot = received_item.slot,
        evidence = "client_replica_snapshot_only",
    }
end

return M
