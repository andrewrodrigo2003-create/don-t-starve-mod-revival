local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

local ItemIdentity = require("modxpector/item_identity")

local function entity(guid, prefab, size)
    local result = {
        GUID = guid,
        prefab = prefab,
        IsValid = function() return true end,
    }
    if size ~= nil then
        result.replica = {
            stackable = {
                StackSize = function() return size end,
            },
        }
    end
    return result
end

local calls = { inventory = 0, equips = 0, active = 0, overflow = 0, target = 0 }
local wood = entity(101, "log", 4)
local axe = entity(102, "axe")
local active = entity(103, "flint")
local backpack_item = entity(104, "cutgrass", 7)
local chest_item = entity(201, "goldnugget", 3)
local overflow = {
    IsBusy = function() return false end,
    GetItems = function()
        calls.overflow = calls.overflow + 1
        return { [1] = backpack_item }
    end,
}
local inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function()
        calls.inventory = calls.inventory + 1
        return { [1] = wood }
    end,
    GetEquips = function()
        calls.equips = calls.equips + 1
        return { hands = axe }
    end,
    GetActiveItem = function()
        calls.active = calls.active + 1
        return active
    end,
    GetOverflowContainer = function() return overflow end,
}
local player = {}
local chest = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return false end,
            IsOpenedBy = function(_, opener) return opener == player end,
            GetItems = function()
                calls.target = calls.target + 1
                return { [2] = chest_item }
            end,
        },
    },
}

local snapshot = ItemIdentity.Capture(inventory, player, chest, pcall)
assert(snapshot.complete == true, "complete client-visible snapshot should pass")
assert(snapshot.player.complete == true and snapshot.target.complete == true)
assert(snapshot.player.item_count == 4 and snapshot.target.item_count == 1)
assert(snapshot.player.by_guid[101].prefab == "log")
assert(snapshot.player.by_guid[101].stack_size == 4)
assert(snapshot.player.by_guid[101].stack_size_source == "replicated")
assert(snapshot.player.by_guid[102].source == "equipment_slot")
assert(snapshot.player.by_guid[103].source == "active_item")
assert(snapshot.player.by_guid[104].source == "overflow_slot")
assert(snapshot.target.by_guid[201].source == "container_slot")
assert(calls.inventory == 1 and calls.equips == 1 and calls.active == 1)
assert(calls.overflow == 1 and calls.target == 1, "each replica collection is read once")

local no_target = ItemIdentity.Capture(inventory, player, nil, pcall)
assert(no_target.complete == true and no_target.target == nil,
    "player-only snapshot should not require a target container")

local duplicate = entity(101, "log")
local duplicate_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return { [1] = wood } end,
    GetEquips = function() return { hands = duplicate } end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local duplicate_result = ItemIdentity.Capture(duplicate_inventory, player, nil, pcall)
assert(duplicate_result.complete == false, "duplicate GUID must fail closed")
assert(#duplicate_result.player.errors > 0)

local invalid_guid = entity(0, "log")
local invalid_guid_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return { [1] = invalid_guid } end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local invalid_guid_result = ItemIdentity.Capture(invalid_guid_inventory, player, nil, pcall)
assert(invalid_guid_result.complete == false, "zero GUID must fail closed")

local invalid_stack = entity(301, "log", 0 / 0)
local invalid_stack_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return { [1] = invalid_stack } end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local invalid_stack_result = ItemIdentity.Capture(invalid_stack_inventory, player, nil, pcall)
assert(invalid_stack_result.complete == false, "NaN stack size must fail closed")

local invalid_entity = entity(401, "log")
invalid_entity.IsValid = function() return false end
local invalid_entity_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return { [1] = invalid_entity } end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local invalid_entity_result = ItemIdentity.Capture(invalid_entity_inventory, player, nil, pcall)
assert(invalid_entity_result.complete == false, "stale entity must fail closed")

local incomplete_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return {} end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
}
local incomplete_result = ItemIdentity.Capture(incomplete_inventory, player, nil, pcall)
assert(incomplete_result.complete == false,
    "missing overflow enumeration API must fail closed")

local closed_chest = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return false end,
            IsOpenedBy = function() return false end,
            GetItems = function() return { [1] = chest_item } end,
        },
    },
}
local closed_result = ItemIdentity.Capture(inventory, player, closed_chest, pcall)
assert(closed_result.complete == false and closed_result.target.complete == false,
    "closed target container must fail closed")

local throwing_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() error("replica unavailable") end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local throwing_result = ItemIdentity.Capture(throwing_inventory, player, nil, pcall)
assert(throwing_result.complete == false, "replica exceptions must fail closed")

local oversized_items = {}
for index = 1, 513 do
    oversized_items[index] = entity(1000 + index, "log")
end
local oversized_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return oversized_items end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local oversized_result = ItemIdentity.Capture(oversized_inventory, player, nil, pcall)
assert(oversized_result.complete == false,
    "inventory collections above the safety limit must fail closed")
assert(oversized_result.player.item_count <= 512,
    "snapshot collector must not retain more than 512 entries")

local moving_stack_size = 2
local moving_item = entity(501, "log")
moving_item.replica = {
    stackable = {
        StackSize = function() return moving_stack_size end,
    },
}
local source_contains_item = true
local target_contains_item = false
local moving_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function()
        return source_contains_item and { [3] = moving_item } or {}
    end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local moving_target = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return false end,
            IsOpenedBy = function(_, opener) return opener == player end,
            GetItems = function()
                return target_contains_item and { [5] = moving_item } or {}
            end,
        },
    },
}
local before_move = ItemIdentity.Capture(moving_inventory, player, moving_target, pcall)
source_contains_item = false
target_contains_item = true
local after_move = ItemIdentity.Capture(moving_inventory, player, moving_target, pcall)
local exact_move = ItemIdentity.CompareExactMove(before_move, after_move, 501, pcall)
assert(exact_move.outcome == "observed_move_candidate",
    "same entity/GUID with unchanged stack evidence should produce only a matched candidate")
assert(exact_move.evidence == "client_replica_snapshot_only",
    "exact move must remain explicitly client-snapshot evidence")
assert(exact_move.causality == "unproven" and exact_move.server_authority == "unverified",
    "client-side correlation must not claim action causality or server authority")

local replacement_item = entity(501, "log", 2)
local replaced_target = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return false end,
            IsOpenedBy = function() return true end,
            GetItems = function() return { [1] = replacement_item } end,
        },
    },
}
local replaced_after = ItemIdentity.Capture(moving_inventory, player, replaced_target, pcall)
local replaced_move = ItemIdentity.CompareExactMove(before_move, replaced_after, 501, pcall)
assert(replaced_move.outcome == "inconclusive",
    "matching GUID with a different local entity reference must not be accepted")

local split_item = entity(502, "log", 1)
source_contains_item = true
target_contains_item = false
moving_stack_size = 1
local split_before = ItemIdentity.Capture(moving_inventory, player, moving_target, pcall)
source_contains_item = true
target_contains_item = true
local split_target = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return false end,
            IsOpenedBy = function() return true end,
            GetItems = function() return { [1] = split_item } end,
        },
    },
}
local split_after = ItemIdentity.Capture(moving_inventory, player, split_target, pcall)
local split_move = ItemIdentity.CompareExactMove(split_before, split_after, 501, pcall)
assert(split_move.outcome == "inconclusive",
    "split stacks with a new GUID must remain inconclusive")

local active_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return {} end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return moving_item end,
    GetOverflowContainer = function() return nil end,
}
local active_before = ItemIdentity.Capture(active_inventory, player, moving_target, pcall)
local active_after = ItemIdentity.Capture(inventory, player, moving_target, pcall)
local active_move = ItemIdentity.CompareExactMove(active_before, active_after, 501, pcall)
assert(active_move.outcome == "inconclusive",
    "active item source must remain unsupported by the narrow exact-move comparator")

local malformed_move = ItemIdentity.CompareExactMove({
    schema = "modxpector/item-identity-capture/v1",
    complete = true,
    player = { complete = true },
    target = { complete = true },
}, after_move, 501, pcall)
assert(malformed_move.outcome == "inconclusive",
    "malformed snapshot maps must fail closed")

moving_item.IsValid = function() return false end
local stale_move = ItemIdentity.CompareExactMove(before_move, after_move, 501, pcall)
assert(stale_move.outcome == "inconclusive",
    "entity removed after capture must fail exact move comparison")

local itemget_event, itemget_reason =
    ItemIdentity.ClassifyReplicaEvent("itemget",
        { item = wood, slot = 2, ignore_stacksize_anim = true }, nil, pcall)
assert(itemget_event == "network_shape_candidate",
    "classified itemget marker should be recognized as a sync candidate")

local preview_itemget = ItemIdentity.ClassifyReplicaEvent("itemget",
    { item = wood, slot = 2 }, nil, pcall)
assert(preview_itemget == "preview_or_unverified",
    "itemget without the sync marker must not be treated as replica sync")

local itemlose_event = ItemIdentity.ClassifyReplicaEvent("itemlose",
    { slot = 2 }, nil, pcall)
assert(itemlose_event == "network_shape_candidate",
    "slot-only itemlose should be recognized as a sync candidate")

local preview_itemlose = ItemIdentity.ClassifyReplicaEvent("itemlose",
    { slot = 2, item = wood }, nil, pcall)
assert(preview_itemlose == "preview_or_unverified",
    "itemlose carrying a preview item must not be treated as replica sync")

local stack_event = ItemIdentity.ClassifyReplicaEvent("stacksizechange",
    { item = wood, stacksize = 4 }, nil, pcall)
assert(stack_event == "network_shape_candidate",
    "network stacksizechange should be recognized as a sync candidate")

local stack_preview = ItemIdentity.ClassifyReplicaEvent("stacksizepreview",
    { stacksize = 4 }, wood, pcall)
assert(stack_preview == "preview_or_unverified",
    "stacksizepreview must remain classified as prediction")

local invalid_stack_event = ItemIdentity.ClassifyReplicaEvent("stacksizechange",
    { item = wood, stacksize = 0 }, nil, pcall)
assert(invalid_stack_event == "unverified",
    "invalid stack size event must fail closed")

local busy_reads = 0
local busy_inventory = {
    classified = { IsBusy = function() return true end },
    GetItems = function()
        busy_reads = busy_reads + 1
        return { [1] = wood }
    end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return nil end,
}
local busy_inventory_result = ItemIdentity.Capture(busy_inventory, player, nil, pcall)
assert(busy_inventory_result.complete == false and busy_reads == 0,
    "busy inventory classified must be rejected before reading predicted items")

local busy_overflow = {
    IsBusy = function() return true end,
    GetItems = function() return { [1] = backpack_item } end,
}
local busy_overflow_inventory = {
    classified = { IsBusy = function() return false end },
    GetItems = function() return {} end,
    GetEquips = function() return {} end,
    GetActiveItem = function() return nil end,
    GetOverflowContainer = function() return busy_overflow end,
}
local busy_overflow_result = ItemIdentity.Capture(busy_overflow_inventory, player, nil, pcall)
assert(busy_overflow_result.complete == false,
    "busy overflow container must make the player snapshot incomplete")

local busy_target = {
    IsValid = function() return true end,
    replica = {
        container = {
            IsBusy = function() return true end,
            IsOpenedBy = function() return true end,
            GetItems = function() return { [1] = chest_item } end,
        },
    },
}
local busy_target_result = ItemIdentity.Capture(inventory, player, busy_target, pcall)
assert(busy_target_result.complete == false and busy_target_result.target.complete == false,
    "busy target container must be rejected before reading predicted items")



local function pickup_inventory(items)
    return {
        classified = { IsBusy = function() return false end },
        GetItems = function() return items end,
        GetEquips = function() return {} end,
        GetActiveItem = function() return nil end,
        GetOverflowContainer = function() return nil end,
    }
end

local pickup_player = {}
local pickup_item = entity(601, "donharpoon", 1)
local pickup_before = ItemIdentity.Capture(
    pickup_inventory({}), pickup_player, nil, pcall)
local pickup_target_before = ItemIdentity.CapturePickupTarget(pickup_item, pcall)
local pickup_after = ItemIdentity.Capture(
    pickup_inventory({ [1] = pickup_item }), pickup_player, nil, pcall)
local pickup_result = ItemIdentity.ComparePickup(
    pickup_before, pickup_after, pickup_target_before, pickup_item, 601, pcall)
assert(pickup_result.outcome == "observed_pickup_candidate",
    "same GUID and entity reference should produce an exact pickup candidate")
assert(pickup_result.evidence == "client_replica_snapshot_only"
    and pickup_result.causality == "unproven"
    and pickup_result.server_authority == "unverified",
    "pickup evidence must not claim causality or server authority")

local similar_item = entity(602, "donharpoon", 1)
local similar_after = ItemIdentity.Capture(
    pickup_inventory({ [1] = similar_item }), pickup_player, nil, pcall)
local similar_result = ItemIdentity.ComparePickup(
    pickup_before, similar_after, pickup_target_before, pickup_item, 601, pcall)
assert(similar_result.outcome == "inconclusive",
    "another item with the same prefab must not confirm the selected pickup")

local fused_item = entity(603, "donharpoon", 2)
local fused_target_before = ItemIdentity.CapturePickupTarget(fused_item, pcall)
fused_item.replica.stackable.StackSize = function() return 3 end
local fused_after = ItemIdentity.Capture(
    pickup_inventory({ [1] = fused_item }), pickup_player, nil, pcall)
local fused_result = ItemIdentity.ComparePickup(
    ItemIdentity.Capture(pickup_inventory({}), pickup_player, nil, pcall),
    fused_after, fused_target_before, fused_item, 603, pcall)
assert(fused_result.outcome == "inconclusive",
    "a stack merge or quantity change must not confirm pickup")

local replaced_original = entity(604, "donharpoon", 1)
local replaced_target_before = ItemIdentity.CapturePickupTarget(replaced_original, pcall)
local replaced_entity = entity(604, "donharpoon", 1)
local replaced_after = ItemIdentity.Capture(
    pickup_inventory({ [1] = replaced_entity }), pickup_player, nil, pcall)
local replaced_result = ItemIdentity.ComparePickup(
    ItemIdentity.Capture(pickup_inventory({}), pickup_player, nil, pcall),
    replaced_after, replaced_target_before, replaced_original, 604, pcall)
assert(replaced_result.outcome == "inconclusive",
    "a replacement entity with a matching GUID must not confirm pickup")

local changed_guid_item = entity(605, "donharpoon", 1)
local changed_guid_before = ItemIdentity.CapturePickupTarget(changed_guid_item, pcall)
changed_guid_item.GUID = 606
local changed_guid_after = ItemIdentity.Capture(
    pickup_inventory({ [1] = changed_guid_item }), pickup_player, nil, pcall)
local changed_guid_result = ItemIdentity.ComparePickup(
    ItemIdentity.Capture(pickup_inventory({}), pickup_player, nil, pcall),
    changed_guid_after, changed_guid_before, changed_guid_item, 605, pcall)
assert(changed_guid_result.outcome == "inconclusive",
    "a GUID change must not silently fall back to prefab counts")

local missing_after = ItemIdentity.Capture(pickup_inventory({}), pickup_player, nil, pcall)
local missing_result = ItemIdentity.ComparePickup(
    pickup_before, missing_after, pickup_target_before, pickup_item, 601, pcall)
assert(missing_result.outcome == "inconclusive",
    "a target that disappears without appearing in inventory must be inconclusive")

local incomplete_inventory = pickup_inventory({})
incomplete_inventory.GetOverflowContainer = nil
local incomplete_after = ItemIdentity.Capture(incomplete_inventory, pickup_player, nil, pcall)
local incomplete_result = ItemIdentity.ComparePickup(
    pickup_before, incomplete_after, pickup_target_before, pickup_item, 601, pcall)
assert(incomplete_result.outcome == "inconclusive",
    "incomplete post-pickup snapshots must be inconclusive")

local incomplete_before_inventory = pickup_inventory({})
incomplete_before_inventory.GetOverflowContainer = nil
local incomplete_before = ItemIdentity.Capture(
    incomplete_before_inventory, pickup_player, nil, pcall)
local incomplete_before_result = ItemIdentity.ComparePickup(
    incomplete_before, pickup_after, pickup_target_before, pickup_item, 601, pcall)
assert(incomplete_before_result.outcome == "inconclusive",
    "incomplete pre-pickup snapshots must be inconclusive")

local invalid_target = entity(607, "donharpoon", 1)
invalid_target.IsValid = function() return false end
local invalid_target_snapshot = ItemIdentity.CapturePickupTarget(invalid_target, pcall)
local invalid_target_result = ItemIdentity.ComparePickup(
    pickup_before, pickup_after, invalid_target_snapshot, invalid_target, 607, pcall)
assert(invalid_target_result.outcome == "inconclusive",
    "an incomplete selected-target snapshot must be inconclusive")

print("ModXpector item identity snapshot tests passed")
