-- Read-only, fail-closed snapshots of client-visible item identity.
-- This module never mutates entities, inventories, containers, or stack sizes.
local M = {}

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function valid_entity(entity)
    if entity == nil or type(entity.IsValid) ~= "function" then
        return false, "entity validity API unavailable"
    end
    local ok, valid = pcall(entity.IsValid, entity)
    if not ok or valid ~= true then
        return false, "entity is invalid or validity check failed"
    end
    return true
end

local function stack_size(entity)
    local replica = entity.replica
    local stackable = type(replica) == "table" and replica.stackable or nil
    if stackable == nil then
        return 1, "not-replicated"
    end
    if type(stackable.StackSize) ~= "function" then
        return nil, "stack size API unavailable"
    end
    local ok, value = pcall(stackable.StackSize, stackable)
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

local function append_item(snapshot, entity, source, slot)
    local valid, reason = valid_entity(entity)
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

    local size, size_source = stack_size(entity)
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

local function append_collection(snapshot, collection, source)
    if type(collection) ~= "table" then
        fail(snapshot, source .. ": item collection is unavailable")
        return
    end
    for slot, entity in pairs(collection) do
        if entity ~= nil then
            append_item(snapshot, entity, source, slot)
        end
    end
end

local function capture_inventory(inventory)
    local snapshot = new_snapshot("player_inventory")
    if type(inventory) ~= "table" then
        fail(snapshot, "inventory replica unavailable")
        return snapshot
    end

    if type(inventory.GetItems) ~= "function" then
        fail(snapshot, "inventory GetItems API unavailable")
    else
        local ok, items = pcall(inventory.GetItems, inventory)
        if not ok then fail(snapshot, "inventory GetItems call failed")
        else append_collection(snapshot, items, "inventory_slot") end
    end

    if type(inventory.GetEquips) ~= "function" then
        fail(snapshot, "inventory GetEquips API unavailable")
    else
        local ok, equips = pcall(inventory.GetEquips, inventory)
        if not ok then fail(snapshot, "inventory GetEquips call failed")
        else append_collection(snapshot, equips, "equipment_slot") end
    end

    if type(inventory.GetActiveItem) ~= "function" then
        fail(snapshot, "inventory GetActiveItem API unavailable")
    else
        local ok, item = pcall(inventory.GetActiveItem, inventory)
        if not ok then fail(snapshot, "inventory GetActiveItem call failed")
        elseif item ~= nil then append_item(snapshot, item, "active_item", "active") end
    end

    if type(inventory.GetOverflowContainer) ~= "function" then
        fail(snapshot, "inventory GetOverflowContainer API unavailable")
    else
        local ok, overflow = pcall(inventory.GetOverflowContainer, inventory)
        if not ok then
            fail(snapshot, "inventory GetOverflowContainer call failed")
        elseif overflow ~= nil then
            if type(overflow.GetItems) ~= "function" then
                fail(snapshot, "overflow container GetItems API unavailable")
            else
                local items_ok, items = pcall(overflow.GetItems, overflow)
                if not items_ok then fail(snapshot, "overflow container GetItems call failed")
                else append_collection(snapshot, items, "overflow_slot") end
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

local function capture_target(target, player)
    local snapshot = new_snapshot("target_container")
    local valid, reason = valid_entity(target)
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
    local open_ok, is_open = pcall(container.IsOpenedBy, container, player)
    if not open_ok or is_open ~= true then
        fail(snapshot, "target container is not confirmed open by the player")
        return snapshot
    end
    if type(container.GetItems) ~= "function" then
        fail(snapshot, "target container GetItems API unavailable")
        return snapshot
    end
    local items_ok, items = pcall(container.GetItems, container)
    if not items_ok then
        fail(snapshot, "target container GetItems call failed")
    else
        append_collection(snapshot, items, "container_slot")
    end

    table.sort(snapshot.items, function(a, b)
        local a_slot, b_slot = tostring(a.slot), tostring(b.slot)
        if a_slot ~= b_slot then return a_slot < b_slot end
        return a.guid < b.guid
    end)
    return snapshot
end

function M.Capture(inventory, player, target)
    local result = {
        schema = "modxpector/item-identity-capture/v1",
        complete = false,
        player = capture_inventory(inventory),
        target = target ~= nil and capture_target(target, player) or nil,
    }
    result.complete = result.player.complete
        and (result.target == nil or result.target.complete)
    return result
end

return M
