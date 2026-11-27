-- luacheck: globals ACTIONS BufferedAction Vector3 GetTime GetValidRecipe EQUIPSLOTS TheSim
local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

ACTIONS = {
    CHOP = { name = "CHOP" }, ATTACK = { name = "ATTACK" },
    WALKTO = { name = "WALKTO" }, MOD_ACTION = { name = "MOD_ACTION" },
    PICKUP = { name = "PICKUP" },
    STORE = { name = "STORE" }, TAKEITEM = { name = "TAKEITEM" },
    TAKESINGLEITEM = { name = "TAKESINGLEITEM" },
}
Vector3 = function(x, y, z) return { x = x, y = y, z = z } end
BufferedAction = function(doer, target, action, invobject, position)
    return { doer = doer, target = target, action = action, invobject = invobject, pos = position }
end
EQUIPSLOTS = { HANDS = "hands", HEAD = "head", BODY = "body", BEARD = "beard" }
local target = {
    prefab = "tree",
    IsValid = function() return true end,
    HasTag = function(_, tag) return tag == "workable" end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
    replica = { health = { GetCurrent = function() return 25 end } },
}
TheSim = { FindEntities = function() return { target } end }
local current_time = 10
GetTime = function() return current_time end
GetValidRecipe = function(name)
    return {
        name = name, product = name,
        placer = name == "structure" and "structure_placer" or nil,
    }
end

local crafted_calls, placed_calls = 0, 0
local player_event_listeners = {}
local pickup_target
local open_container = {
    prefab = "treasurechest",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 1, 0, 0 end },
    replica = {
        container = {
            IsOpenedBy = function() return true end,
            Has = function(_, prefab)
                if prefab == "goldnugget" then return true, 3 end
                return false, 0
            end,
        },
    },
}
local player
player = {
    prefab = "wilson",
    components = { playercontroller = { DoAction = function(self, action)
        self.last_action = action
        if action.action == ACTIONS.CHOP then player.last_chop_action = action end
        if action.action == ACTIONS.PICKUP then
            player.last_pickup_action = action
            player.picked_up = true
            player:PushEvent("itemget", {
                item = pickup_target,
                slot = 1,
                ignore_stacksize_anim = true,
            })
        end
    end } },
    replica = {
        inventory = {
            GetItems = function()
                return player ~= nil and player.picked_up == true and pickup_target ~= nil
                    and { [1] = pickup_target } or {}
            end,
            GetEquips = function() return {} end,
            GetActiveItem = function() return nil end,
            FindItem = function(_, fn)
                local items = { { prefab = "cutgrass" } }
                if player ~= nil and player.crafted_recipe == "axe" then
                    items[#items + 1] = { prefab = "axe" }
                end
                for _, item in ipairs(items) do
                    if fn(item) then return item end
                end
                return nil
            end,
            Has = function(_, prefab, count)
                local found = prefab == "cutgrass" and (player.picked_up and 3 or 2)
                    or prefab == "axe" and (player.crafted_recipe == "axe" and 1 or 0) or 0
                return found >= count, found
            end,
            GetOpenContainers = function() return { [open_container] = true } end,
            GetOverflowContainer = function() return nil end,
            GetEquippedItem = function(_, slot)
                return slot == "hands" and { prefab = "axe" } or nil
            end,
            classified = {
                IsValid = function() return true end,
                IsBusy = function() return false end,
            },
        },
        health = { GetCurrent = function() return 120 end },
        hunger = { GetCurrent = function() return 80 end },
        sanity = { GetCurrent = function() return 90 end },
        builder = {
            KnowsRecipe = function() return true end,
            HasIngredients = function() return true end,
            MakeRecipeFromMenu = function(_, recipe)
                crafted_calls = crafted_calls + 1
                player.crafted_recipe = recipe.name
            end,
            BufferBuild = function(self, recipe) self.buffered = self.buffered or {}; self.buffered[recipe] = true end,
            IsBuildBuffered = function(self, recipe) return self.buffered ~= nil and self.buffered[recipe] == true end,
            CanBuildAtPoint = function(_, point, _, rotation)
                return point.x == 2 and point.z == 3 and rotation == 0
            end,
            MakeRecipeAtPoint = function(_, recipe, point, rotation)
                placed_calls = placed_calls + 1
                player.placed_recipe = {
                    name = recipe.name, point = point, rotation = rotation,
                }
            end,
        },
    },
    Transform = { GetWorldPosition = function() return 0, 0, 0 end },
    IsValid = function() return true end,
    ListenForEvent = function(self, event, callback, source)
        player_event_listeners[event] = player_event_listeners[event] or {}
        table.insert(player_event_listeners[event], { callback = callback, source = source })
    end,
    RemoveEventCallback = function(self, event, callback, source)
        local listeners = player_event_listeners[event] or {}
        for index = #listeners, 1, -1 do
            local listener = listeners[index]
            if listener.callback == callback and listener.source == source then
                table.remove(listeners, index)
            end
        end
    end,
    PushEvent = function(self, event, data)
        local listeners = player_event_listeners[event] or {}
        local snapshot = {}
        for index, listener in ipairs(listeners) do snapshot[index] = listener end
        for _, listener in ipairs(snapshot) do
            if listener.source == nil or listener.source == self then
                listener.callback(self, data)
            end
        end
    end,
    ListenerExists = function(self, event, callback, source)
        for _, listener in ipairs(player_event_listeners[event] or {}) do
            if listener.callback == callback and listener.source == source then return true end
        end
        return false
    end,
    ListenerCount = function(self, event)
        return #(player_event_listeners[event] or {})
    end,
    DoTaskInTime = function(_, delay, fn) current_time = current_time + (delay or 0); fn() end,
    GetBufferedAction = function() return nil end,
}
local structure_target = {
    prefab = "structure",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 2, 0, 3 end },
}
pickup_target = {
    GUID = 501,
    prefab = "cutgrass",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 1, 0, 0 end },
}
pickup_target._event_listeners = {}
pickup_target.ListenForEvent = function(self, event, callback)
    self._event_listeners[event] = self._event_listeners[event] or {}
    table.insert(self._event_listeners[event], callback)
end
pickup_target.RemoveEventCallback = function(self, event, callback)
    local listeners = self._event_listeners[event] or {}
    for index = #listeners, 1, -1 do
        if listeners[index] == callback then table.remove(listeners, index) end
    end
end
pickup_target.ListenerExists = function(self, event, callback)
    for _, listener in ipairs(self._event_listeners[event] or {}) do
        if listener == callback then return true end
    end
    return false
end
pickup_target.ListenerCount = function(self, event)
    return #(self._event_listeners[event] or {})
end
local birdcage_target = {
    prefab = "birdcage",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 2, 0, 0 end },
}
TheSim.FindEntities = function()
    local found = { target, pickup_target, open_container, birdcage_target }
    if player ~= nil and player.placed_recipe ~= nil then found[#found + 1] = structure_target end
    return found
end
local VirtualPlayer = require("modxpector/virtual_player_client")
local finished
local controller
controller = VirtualPlayer.new(player, {
    allowed_actions = { "MOD_ACTION" },
    allowed_prefabs = { "cutgrass", "axe", "tree", "structure", "goldnugget", "treasurechest", "birdcage" },
    allowed_recipes = { "axe", "structure" },
    send_rpc = function(kind, request_id, value, count, _x, _z, step_index, run_id)
        assert(run_id == "live-vp-contract-001",
            "effectful RPC must carry the active plan run ID")
        if kind == "unlock_recipe" then
            assert(value == "axe" and step_index == 4,
                "unlock RPC must carry its exact 1-based plan step")
            controller:OnRPCResult(request_id, true, "unlocked recipe axe")
        else
            assert(kind == "spawn_item" and value == "cutgrass" and count == 2 and step_index == 3,
                "spawn RPC must carry its exact 1-based plan step")
            controller:OnRPCResult(request_id, true, "spawned test items")
        end
    end,
    on_finished = function(report) finished = report end,
})
-- Target selection ignores stale/malformed entities and uses GUID to break distance ties.
local original_target_finder = TheSim.FindEntities
local tied_target_high_guid = {
    GUID = 42, prefab = "tree",
    IsValid = function() return true end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
}
local tied_target_low_guid = {
    GUID = 7, prefab = "tree",
    IsValid = function() return true end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
}
local stale_target = {
    GUID = 1, prefab = "tree",
    IsValid = function() error("entity was removed during scan") end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
}
local invalid_position_target = {
    GUID = 0, prefab = "tree",
    IsValid = function() return true end,
    Transform = { GetWorldPosition = function() return 0 / 0, 0, 0 end },
}
TheSim.FindEntities = function()
    return { tied_target_high_guid, stale_target, invalid_position_target, tied_target_low_guid }
end
assert(controller:ResolveTarget({ prefab = "tree", radius = 0 / 0 }) == tied_target_low_guid,
    "target selection must skip stale/non-finite entities and choose the lowest GUID on distance ties")
TheSim.FindEntities = original_target_finder

local plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "live-vp-contract-001",
    allowed_recipes = { "axe", "structure" },
    steps = {
        { kind = "action", action = "CHOP", timeout = 5 },
        { kind = "wait", seconds = 0 },
        { kind = "spawn_item", prefab = "cutgrass", count = 2 },
        { kind = "unlock_recipe", recipe = "axe" },
        { kind = "craft", recipe = "axe" },
        { kind = "craft_at_point", recipe = "structure", position = { x = 2, z = 3 }, rotation = 0 },
        { kind = "assert", assertion = { kind = "player_has_item", prefab = "cutgrass" } },
        { kind = "assert", assertion = { kind = "player_has_item", prefab = "goldnugget" } },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "goldnugget", count = 3 } },
        { kind = "assert", assertion = { kind = "player_health_gte", value = 100 } },
        { kind = "assert", assertion = { kind = "player_hunger_gte", value = 70 } },
        { kind = "assert", assertion = { kind = "player_sanity_gte", value = 80 } },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 2 }, verifies_step = 3 },
        { kind = "assert", assertion = { kind = "player_knows_recipe", recipe = "axe" }, verifies_step = 4 },
        { kind = "assert", assertion = { kind = "player_has_item", prefab = "axe" }, verifies_step = 5 },
        { kind = "assert", assertion = { kind = "player_item_count_increased", prefab = "axe", target_step = 5, count = 1 }, verifies_step = 5 },
        { kind = "assert", assertion = { kind = "target_exists", target = { prefab = "structure" } }, verifies_step = 6 },
        { kind = "assert", assertion = { kind = "player_equipped", slot = "HANDS", prefab = "axe" } },
        { kind = "assert", assertion = { kind = "player_near_target", target = { prefab = "tree" }, radius = 5 } },
        { kind = "assert", assertion = { kind = "target_exists", target = { prefab = "tree" } } },
        { kind = "assert", assertion = { kind = "target_health_lte", target = { prefab = "tree" }, value = 30 }, verifies_step = 1 },
        { kind = "assert", assertion = { kind = "target_dead", target = { prefab = "tree" }, expected = false } },
        { kind = "assert", assertion = { kind = "target_has_tag", target = { prefab = "tree" }, tag = "workable" } },
        { kind = "action", action = "PICKUP", target = { prefab = "cutgrass" }, target_required = true },
        { kind = "assert", assertion = { kind = "pickup_target_collected", prefab = "cutgrass", target_step = 24 }, verifies_step = 24 },
    },
}
assert(controller:Start(plan))
assert(finished ~= nil and finished.running == false)
assert(finished.run_id == plan.run_id)
assert(type(finished.started_at) == "number" and type(finished.finished_at) == "number")
assert(type(finished.duration_seconds) == "number" and finished.duration_seconds >= 0)
assert(finished.results[1].run_id == plan.run_id)
assert(type(finished.results[1].timestamp) == "number")
assert(type(finished.results[1].elapsed_seconds) == "number")
local saw_spawn_metadata, saw_recipe_metadata = false, false
for _, result in ipairs(finished.results) do
    if result.kind == "spawn_item" and result.status == "completed" then
        assert(result.target_prefab == "cutgrass" and result.recipe == nil)        saw_spawn_metadata = true
    elseif result.kind == "craft" and result.status == "submitted_unverified" then
        assert(result.recipe == "axe" and result.target_prefab == nil)
        saw_recipe_metadata = true
    end
end
assert(saw_spawn_metadata and saw_recipe_metadata,
    "step reports must distinguish spawned prefabs from recipe identifiers")
assert(player.last_chop_action.action == ACTIONS.CHOP)
assert(finished.results[1].status == "started")
assert(finished.results[2].status == "cleared_unverified")
assert(finished.assertions_total == 18 and finished.assertions_passed == 18)
assert(finished.outcome == "passed")
assert(finished.steps_completed == #plan.steps,
    "steps_completed must count plan steps, not result events")
assert(finished.steps_verified == 6 and finished.steps_unverified == 0,
    "all six side-effect steps must have explicit post-action verification")
assert(finished.verification_assertions_passed == 7,
    "craft must remain pending until both postconditions pass")
assert(player.last_pickup_action.action == ACTIONS.PICKUP and player.picked_up == true)
local pickup_observation = finished.step_event_observer_results[24]
assert(pickup_observation ~= nil and pickup_observation.target_item_guid == pickup_target.GUID,
    "PICKUP should include a step-scoped observer record correlated to the selected item GUID")
assert(pickup_observation.target_item_observed == true,
    "PICKUP observer should record the matching client-replica itemget event")
assert(pickup_observation.evidence == "client_replica_event_shape_only"
    and pickup_observation.causality == "unproven"
    and pickup_observation.server_authority == "unverified",
    "observer evidence must not claim causal or server-authoritative proof")
assert(pickup_observation.cleanup_complete == true
    and finished.step_event_observer_cleanup_pending == false,
    "PICKUP observer listeners must be removed before the run finishes")
assert(player:ListenerCount("itemget") == 0
    and player:ListenerCount("itemlose") == 0
    and player:ListenerCount("onremove") == 0,
    "Virtual Player must clean event listeners after the run")
local equipped_invobject_action = controller:BuildAction({ kind = "action", action = "MOD_ACTION", invobject = "axe" })
assert(equipped_invobject_action.invobject ~= nil and equipped_invobject_action.invobject.prefab == "axe",
    "an equipped allowlisted tool must be usable as an explicit action inventory object")
assert(player.crafted_recipe == "axe" and crafted_calls == 1)
assert(player.placed_recipe ~= nil and player.placed_recipe.name == "structure" and placed_calls == 1)
assert(player.placed_recipe.point.x == 2 and player.placed_recipe.point.z == 3)
target.replica.health.GetCurrent = function() return 0 end
local dead_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" } })
assert(dead_result.actual == true and dead_result.passed == true)
target.replica.health.GetCurrent = function() return 25 end
local alive_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" }, expected = false })
assert(alive_result.actual == false and alive_result.passed == true)
local accessible_gold = controller:_evaluate_assertion({ kind = "player_has_item", prefab = "goldnugget" })
local carried_gold = controller:_evaluate_assertion({ kind = "player_inventory_has_item", prefab = "goldnugget", expected = false })
local chest_gold = controller:_evaluate_assertion({
    kind = "container_has_item", target = { prefab = "treasurechest" }, prefab = "goldnugget", count = 3,
})
assert(accessible_gold.passed == true and carried_gold.actual == false and carried_gold.passed == true,
    "carried-inventory assertions must exclude items stored in open chests")
assert(chest_gold.actual == true and chest_gold.passed == true,
    "container assertions must read the target container replica count")
local invalid_container_count_ok = pcall(function()
    controller:_evaluate_assertion({
        kind = "container_has_item", target = { prefab = "treasurechest" }, prefab = "goldnugget", count = 1.5,
    })
end)
assert(not invalid_container_count_ok, "fractional container assertion counts must be rejected")

local previous_index_for_container = controller.index
local previous_target_for_container = controller.step_targets[1]
controller.index = 2
controller.step_targets[1] = {
    prefab = "treasurechest",
    IsValid = function() return false end,
    replica = { container = { Has = function() return true, 99 end } },
}
local stale_target_container_ok = pcall(function()
    controller:_evaluate_assertion({
        kind = "container_has_item", target_step = 1, prefab = "goldnugget", count = 1,
    })
end)
assert(not stale_target_container_ok,
    "container assertion must reject a removed captured target before reading its replica")
controller.step_targets[1] = previous_target_for_container
controller.index = previous_index_for_container

local stale_open_container = {
    IsValid = function() return false end,
    replica = { container = { Has = function() return true, 99 end } },
}
local stale_inventory = {
    Has = function() return false, 0 end,
    GetOpenContainers = function() return { [stale_open_container] = true } end,
    GetOverflowContainer = function() return nil end,
    GetEquippedItem = function() return nil end,
}
assert(controller:_count_player_prefab(stale_inventory, "goldnugget", true) == 0,
    "removed open containers must not contribute ghost inventory counts")


-- Invalid replica counts must fail closed rather than being normalized to zero.
local negative_inventory_count_ok = pcall(function()
    controller:_count_player_prefab({ Has = function() return false, -5 end }, "goldnugget", false)
end)
assert(not negative_inventory_count_ok, "negative inventory counts must be rejected")
local nan_inventory_count_ok = pcall(function()
    controller:_count_player_prefab({ Has = function() return false, 0 / 0 end }, "goldnugget", false)
end)
assert(not nan_inventory_count_ok, "NaN inventory counts must be rejected")
local invalid_count_container = {
    IsValid = function() return true end,
    replica = { container = { Has = function() return false, -9 end } },
}
local invalid_open_count_ok = pcall(function()
    controller:_count_player_prefab({
        Has = function() return false, 0 end,
        GetOpenContainers = function() return { [invalid_count_container] = true } end,
        GetOverflowContainer = function() return nil end,
        GetEquippedItem = function() return nil end,
    }, "goldnugget", true)
end)
assert(not invalid_open_count_ok, "negative open-container counts must be rejected")
TheSim.FindEntities = function() return {} end
local removed_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" } })
assert(removed_result.actual == nil and removed_result.inconclusive == true and removed_result.passed == false,
    "a missing target without a death event must not be reported as confirmed dead")

-- A captured entity reference must be revalidated before every target assertion.
local previous_index = controller.index
local previous_step_target = controller.step_targets[1]
local removed_captured_target = {
    prefab = "tree",
    IsValid = function() return false end,
    replica = { health = { GetCurrent = function() return 0 end } },
    HasTag = function() return true end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
}
controller.index = 2
controller.step_targets[1] = removed_captured_target
local stale_exists = controller:_evaluate_assertion({
    kind = "target_exists", target_step = 1, expected = false,
})
local stale_dead = controller:_evaluate_assertion({
    kind = "target_dead", target_step = 1,
})
local stale_tag = controller:_evaluate_assertion({
    kind = "target_has_tag", target_step = 1, tag = "workable", expected = false,
})
local stale_near = controller:_evaluate_assertion({
    kind = "player_near_target", target_step = 1, expected = false,
})
assert(stale_exists.passed and stale_dead.inconclusive and stale_tag.inconclusive and stale_near.inconclusive,
    "stale captured targets must not satisfy negative tag or proximity assertions")

local previous_index_for_near = controller.index
local previous_target_for_near = controller.step_targets[1]
controller.index = 2
controller.step_targets[1] = target
local invalid_radius_negative = pcall(function()
    controller:_evaluate_assertion({ kind = "player_near_target", target_step = 1, radius = -1 })
end)
local invalid_radius_large = pcall(function()
    controller:_evaluate_assertion({ kind = "player_near_target", target_step = 1, radius = 41 })
end)
local invalid_radius_nan = pcall(function()
    controller:_evaluate_assertion({ kind = "player_near_target", target_step = 1, radius = 0 / 0 })
end)
assert(not invalid_radius_negative and not invalid_radius_large and not invalid_radius_nan,
    "near-target assertion must reject negative, excessive, and non-finite radii")

local malformed_position_target = {
    prefab = "tree",
    IsValid = function() return true end,
    Transform = { GetWorldPosition = function() return 0 / 0, 0, 0 end },
}
controller.step_targets[1] = malformed_position_target
local malformed_near = controller:_evaluate_assertion({
    kind = "player_near_target", target_step = 1, expected = false,
})
assert(malformed_near.inconclusive and not malformed_near.passed,
    "invalid world coordinates must be inconclusive, not pass a negative proximity assertion")
controller.step_targets[1] = previous_target_for_near
controller.index = previous_index_for_near
controller.target_death_events[1] = true
assert(controller:_is_target_entity_dead(removed_captured_target, 1) == true,
    "a captured death event must remain authoritative after the target entity is removed")
controller.target_death_events[1] = false
local stale_health_ok = pcall(function()
    controller:_evaluate_assertion({ kind = "target_health_lte", target_step = 1, value = 0 })
end)
assert(not stale_health_ok, "health assertions must reject a stale captured target")
controller.step_targets[1] = previous_step_target
controller.index = previous_index
assert(finished.results[#finished.results].status == "completed")

local target_ok, target_err = pcall(function() controller:ResolveTarget({ prefab = "modxpector_unapproved_test_prefab" }) end)
assert(not target_ok and string.find(tostring(target_err), "allowlist", 1, true))
local tag_only_ok = pcall(function() controller:ResolveTarget({ tag = "workable" }) end)
assert(not tag_only_ok)
local custom = controller:BuildAction({ action = "MOD_ACTION", invobject = "cutgrass" })
assert(custom.action == ACTIONS.MOD_ACTION and custom.invobject.prefab == "cutgrass")
local ok, err = pcall(function() controller:BuildAction({ action = "UNSAFE_EXEC" }) end)
assert(not ok and string.find(tostring(err), "not allowed", 1, true))
for _, blocked_action in ipairs({ "STORE", "TAKEITEM", "TAKESINGLEITEM" }) do
    controller.allowed_actions[blocked_action] = true
    local blocked_ok, blocked_error = pcall(function()
        return controller:BuildAction({
            kind = "action", action = blocked_action,
            target = { prefab = "birdcage", radius = 10 },
            target_required = true, invobject = "cutgrass",
        }, birdcage_target)
    end)
    assert(not blocked_ok and string.find(tostring(blocked_error), "blocked", 1, true),
        blocked_action .. " must remain blocked even when a plan attempts to allow it")
    controller.allowed_actions[blocked_action] = nil
end
local invalid_take_ok, invalid_take_error = pcall(function() controller:BuildAction({ kind = "action", action = "TAKE" }) end)
assert(not invalid_take_ok and string.find(tostring(invalid_take_error), "not allowed", 1, true),
    "nonexistent TAKE action must not be accepted in place of TAKEITEM/TAKESINGLEITEM")
local invalid_container_count_target = {
    prefab = "treasurechest",
    IsValid = function() return true end,
    replica = { container = {
        IsOpenedBy = function() return true end,
        Has = function() return true, -5 end,
    } },
}
local invalid_container_count_ok = pcall(function()
    controller:_evaluate_assertion({
        kind = "container_has_item", target = invalid_container_count_target,
        prefab = "goldnugget", count = 1,
    })
end)
assert(not invalid_container_count_ok,
    "container assertions must reject negative replica counts instead of normalizing them to zero")
local nan_container_count_target = {
    prefab = "treasurechest",
    IsValid = function() return true end,
    replica = { container = {
        IsOpenedBy = function() return true end,
        Has = function() return true, 0 / 0 end,
    } },
}
local nan_container_count_ok = pcall(function()
    controller:_evaluate_assertion({
        kind = "container_has_item", target = nan_container_count_target,
        prefab = "goldnugget", count = 1,
    })
end)
assert(not nan_container_count_ok,
    "container assertions must reject NaN replica counts")

print("MODXPECTOR_LIVE_VIRTUAL_PLAYER_CONTRACT_OK")


-- A placer recipe that never enters the BuilderReplica buffer must fail closed.
local timeout_finished
local original_buffer_build = player.replica.builder.BufferBuild
player.replica.builder.BufferBuild = function() end
player.replica.builder.buffered = nil
local timeout_controller = VirtualPlayer.new(player, {
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = { "structure" },
    on_finished = function(report) timeout_finished = report end,
})
assert(timeout_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "craft_at_point", recipe = "structure", position = { x = 2, z = 3 }, timeout = 1 } },
}))
assert(timeout_finished ~= nil and timeout_finished.outcome == "failed")
assert(timeout_finished.failure == "craft_at_point buffer timeout")
player.replica.builder.BufferBuild = original_buffer_build
print("MODXPECTOR_PLACER_TIMEOUT_CONTRACT_OK")


-- Craft and placer-craft must fail closed when the recipe is absent from the plan allowlist.
local denied_craft_report
local denied_craft = VirtualPlayer.new(player, {
    allowed_recipes = { "axe" },
    on_finished = function(report) denied_craft_report = report end,
})
assert(denied_craft:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "craft", recipe = "structure" } },
}))
assert(denied_craft_report ~= nil and denied_craft_report.outcome == "failed")
assert(string.find(denied_craft_report.failure, "allowlist", 1, true))
assert(player.crafted_recipe == "axe" and crafted_calls == 1, "disallowed recipe must not be crafted")

local denied_placer_report
local denied_placer = VirtualPlayer.new(player, {
    allowed_recipes = { "axe" },
    on_finished = function(report) denied_placer_report = report end,
})
assert(denied_placer:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "craft_at_point", recipe = "structure", position = { x = 2, z = 3 } } },
}))
assert(denied_placer_report ~= nil and denied_placer_report.outcome == "failed")
assert(string.find(denied_placer_report.failure, "allowlist", 1, true))
assert(player.placed_recipe ~= nil and player.placed_recipe.name == "structure" and placed_calls == 1,
    "disallowed placer recipe must not be submitted again")
print("MODXPECTOR_CRAFT_RECIPE_ALLOWLIST_CONTRACT_OK")

-- Reports count terminally processed plan steps, not the detailed result events.
local partial_failure_report
local partial_failure = VirtualPlayer.new(player, {
    on_finished = function(report) partial_failure_report = report end,
})
assert(partial_failure:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = {
        { kind = "assert", assertion = { kind = "player_health_gte", value = 100 } },
        { kind = "assert", assertion = { kind = "player_health_gte", value = 200 } },
    },
}))
assert(partial_failure_report ~= nil and partial_failure_report.outcome == "failed")
assert(partial_failure_report.steps_completed == 1,
    "a failed current step must not increment steps_completed")
assert(partial_failure_report.assertions_total == 2 and partial_failure_report.assertions_passed == 1)
print("MODXPECTOR_VIRTUAL_PLAYER_STEP_COUNT_CONTRACT_OK")

-- Client-side RPC steps must obey the same plan allowlists before reaching the master.
local denied_rpc_calls = 0
local denied_unlock_report
local denied_unlock
denied_unlock = VirtualPlayer.new(player, {
    allowed_recipes = {},
    send_rpc = function(kind, request_id)
        denied_rpc_calls = denied_rpc_calls + 1
        denied_unlock:OnRPCResult(request_id, false, "unexpected unlock RPC")
    end,
    on_finished = function(report) denied_unlock_report = report end,
})
assert(denied_unlock:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "unlock_recipe", recipe = "axe" } },
}))
assert(denied_unlock_report ~= nil and denied_unlock_report.outcome == "failed")
assert(string.find(denied_unlock_report.failure, "allowlist", 1, true))
assert(denied_rpc_calls == 0, "disallowed unlock must not reach the master RPC")

local denied_spawn_report
local denied_spawn
denied_spawn = VirtualPlayer.new(player, {
    allowed_prefabs = {},
    send_rpc = function(kind, request_id)
        denied_rpc_calls = denied_rpc_calls + 1
        denied_spawn:OnRPCResult(request_id, false, "unexpected spawn RPC")
    end,
    on_finished = function(report) denied_spawn_report = report end,
})
assert(denied_spawn:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "spawn_item", prefab = "cutgrass", count = 1 } },
}))
assert(denied_spawn_report ~= nil and denied_spawn_report.outcome == "failed")
assert(string.find(denied_spawn_report.failure, "allowlist", 1, true))
assert(denied_rpc_calls == 0, "disallowed spawn must not reach the master RPC")

local invalid_count_report
local invalid_count_calls = 0
local invalid_count = VirtualPlayer.new(player, {
    allowed_prefabs = { "cutgrass" },
    send_rpc = function() invalid_count_calls = invalid_count_calls + 1 end,
    on_finished = function(report) invalid_count_report = report end,
})
assert(invalid_count:Start({
    schema = "modxpector/test-plan/v1",    enabled = true,
    steps = { { kind = "spawn_item", prefab = "cutgrass", count = 1.5 } },
}))
assert(invalid_count_report ~= nil and invalid_count_report.outcome == "failed")
assert(invalid_count_report.failure == "invalid spawn count")
assert(invalid_count_calls == 0, "fractional spawn count must not reach the master RPC")
print("MODXPECTOR_VIRTUAL_PLAYER_RPC_ALLOWLIST_CONTRACT_OK")

-- Runtime exceptions in PlayerController, scheduler callbacks and RPC dispatch
-- must terminate the run with a structured failure instead of leaving it stuck.
local original_do_action = player.components.playercontroller.DoAction
local action_runtime_report
player.components.playercontroller.DoAction = function()
    error("simulated PlayerController failure")
end
local action_runtime_controller = VirtualPlayer.new(player, {
    allowed_prefabs = { "tree" },
    on_finished = function(report) action_runtime_report = report end,
})
assert(action_runtime_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "action", action = "CHOP" } },
}))
assert(action_runtime_report ~= nil and action_runtime_report.running == false)
assert(action_runtime_report.outcome == "failed")
assert(string.find(action_runtime_report.failure, "simulated PlayerController failure", 1, true))
player.components.playercontroller.DoAction = original_do_action

local original_task_scheduler = player.DoTaskInTime
local scheduler_runtime_report
player.DoTaskInTime = function()
    error("simulated task scheduler failure")
end
local scheduler_runtime_controller = VirtualPlayer.new(player, {
    on_finished = function(report) scheduler_runtime_report = report end,
})
assert(scheduler_runtime_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "wait", seconds = 1 } },
}))
assert(scheduler_runtime_report ~= nil and scheduler_runtime_report.running == false)
assert(scheduler_runtime_report.outcome == "failed")
assert(string.find(scheduler_runtime_report.failure, "simulated task scheduler failure", 1, true))
player.DoTaskInTime = original_task_scheduler

local original_get_buffered_action = player.GetBufferedAction
local buffered_runtime_report
player.GetBufferedAction = function()
    error("simulated buffered action read failure")
end
local buffered_runtime_controller = VirtualPlayer.new(player, {
    on_finished = function(report) buffered_runtime_report = report end,
})
assert(buffered_runtime_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "action", action = "CHOP" } },
}))
assert(buffered_runtime_report ~= nil and buffered_runtime_report.running == false)
assert(buffered_runtime_report.outcome == "failed")
assert(string.find(buffered_runtime_report.failure, "simulated buffered action read failure", 1, true))
player.GetBufferedAction = original_get_buffered_action

local rpc_runtime_report
local rpc_runtime_controller = VirtualPlayer.new(player, {
    allowed_recipes = { "axe" },
    send_rpc = function()
        error("simulated RPC dispatch failure")
    end,
    on_finished = function(report) rpc_runtime_report = report end,
})
assert(rpc_runtime_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "unlock_recipe", recipe = "axe" } },
}))
assert(rpc_runtime_report ~= nil and rpc_runtime_report.running == false)
assert(rpc_runtime_report.outcome == "failed")
assert(string.find(rpc_runtime_report.failure, "simulated RPC dispatch failure", 1, true))

local callback_runtime_report
local callback_runtime_controller = VirtualPlayer.new(player, {
    on_finished = function() error("simulated report callback failure") end,
})
assert(callback_runtime_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "assert", assertion = { kind = "player_health_gte", value = 100 } } },
}))
callback_runtime_report = callback_runtime_controller:GetReport()
assert(callback_runtime_report.running == false and callback_runtime_report.outcome == "passed")
assert(string.find(callback_runtime_report.on_finished_error, "simulated report callback failure", 1, true))
print("MODXPECTOR_VIRTUAL_PLAYER_RUNTIME_GUARD_CONTRACT_OK")

-- A passing unrelated assertion must not turn an unverified action into a passed run.
local unverified_report
local unverified_controller = VirtualPlayer.new(player, {
    allowed_prefabs = { "tree" },
    on_finished = function(report) unverified_report = report end,
})
assert(unverified_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = {
        { kind = "action", action = "CHOP" },
        { kind = "assert", assertion = { kind = "player_health_gte", value = 100 } },
    },
}))
assert(unverified_report ~= nil and unverified_report.outcome == "inconclusive")
assert(unverified_report.steps_unverified == 1 and unverified_report.unverified_step_indices[1] == 1)
print("MODXPECTOR_VIRTUAL_PLAYER_POST_ACTION_VERIFICATION_CONTRACT_OK")

-- A broken entity validity accessor must not prevent the final failure report.
local original_is_valid = player.IsValid
local invalid_player_report
local invalid_player_controller = VirtualPlayer.new(player, {
    on_finished = function(report) invalid_player_report = report end,
})
player.IsValid = function()
    error("simulated player validity failure")
end
assert(invalid_player_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "wait", seconds = 1 } },
}))
assert(invalid_player_report ~= nil and invalid_player_report.running == false)
assert(invalid_player_report.outcome == "failed")
assert(invalid_player_report.player == nil)
player.IsValid = original_is_valid
print("MODXPECTOR_VIRTUAL_PLAYER_FINAL_REPORT_GUARD_CONTRACT_OK")

-- A foreign BufferedAction must not be mistaken for completion of the Virtual Player action.
local original_buffer_reader = player.GetBufferedAction
local replaced_action_report
player.GetBufferedAction = function()
    return { action = ACTIONS.WALKTO }
end
local replaced_action_controller = VirtualPlayer.new(player, {
    on_finished = function(report) replaced_action_report = report end,
})
assert(replaced_action_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "action", action = "CHOP" } },
}))
assert(replaced_action_report ~= nil and replaced_action_report.outcome == "failed")
assert(replaced_action_report.failure == "buffered action replaced at step 1")
player.GetBufferedAction = original_buffer_reader
local invalid_inventory_count_report
local invalid_inventory_count_controller = VirtualPlayer.new(player, {
    allowed_prefabs = { "cutgrass" },
    on_finished = function(report) invalid_inventory_count_report = report end,
})
assert(invalid_inventory_count_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 1.5 } } },
}))
assert(invalid_inventory_count_report ~= nil and invalid_inventory_count_report.outcome == "failed")
assert(string.find(invalid_inventory_count_report.failure, "integer between 1 and 10000", 1, true))


do
-- A pre-existing item must not falsely verify a pickup that changed nothing.
local baseline_guard_report
local baseline_guard = VirtualPlayer.new(player, {
    allowed_prefabs = { "cutgrass" },
    on_finished = function(report) baseline_guard_report = report end,
})
local legacy_pickup_accepted = pcall(function()
    baseline_guard:Start({
        schema = "modxpector/test-plan/v1",
        enabled = true,
        steps = {
            { kind = "action", action = "PICKUP",
                target = { prefab = "cutgrass" }, target_required = true },
            { kind = "assert", assertion = {
                kind = "player_item_count_increased",
                prefab = "cutgrass", target_step = 1, count = 1,
            }, verifies_step = 1 },
        },
    })
end)
assert(legacy_pickup_accepted == false,
    "aggregate prefab count must not be accepted as a PICKUP identity postcondition")



end

do
-- PICKUP uses an isolated before/after inventory delta, not the container-transfer oracle.
local previous_pickup_state = player.picked_up
player.picked_up = false
local pickup_controller = VirtualPlayer.new(player, { allowed_prefabs = { "cutgrass" } })
pickup_controller.queue = {
    { kind = "action", action = "PICKUP", target_required = true },
    { kind = "assert", assertion = {
        kind = "pickup_target_collected",
        prefab = "cutgrass", target_step = 1,
    }, verifies_step = 1 },
}
pickup_controller.index = 1
local pickup_baseline_ok, pickup_baseline_error =
    pickup_controller:_capture_step_pickup_baseline(1, pickup_target)
assert(pickup_baseline_ok == true, tostring(pickup_baseline_error))
player.picked_up = true
pickup_controller.index = 2
local pickup_delta = pickup_controller:_evaluate_assertion({
    kind = "pickup_target_collected",
    prefab = "cutgrass", target_step = 1,
})
assert(pickup_delta.passed == true,
    "PICKUP should pass only after the exact target GUID and entity reference appear in inventory")
player.picked_up = false
local event_only_controller = VirtualPlayer.new(player, { allowed_prefabs = { "cutgrass" } })
event_only_controller.queue = {
    { kind = "action", action = "PICKUP", target_required = true },
    { kind = "assert", assertion = {
        kind = "pickup_target_collected", prefab = "cutgrass", target_step = 1,
    }, verifies_step = 1 },
}
event_only_controller.index = 1
local event_baseline_ok = event_only_controller:_capture_step_pickup_baseline(1, pickup_target)
assert(event_baseline_ok == true)
player:PushEvent("itemget", { item = pickup_target, slot = 1 })
player:PushEvent("itemget", { item = pickup_target, slot = 1 })
event_only_controller.index = 2
local event_only_result = event_only_controller:_evaluate_assertion({
    kind = "pickup_target_collected", prefab = "cutgrass", target_step = 1,
})
assert(event_only_result.inconclusive == true and event_only_result.passed == false,
    "duplicate client itemget events without an exact inventory transfer must remain inconclusive")
player.picked_up = previous_pickup_state

end

print("MODXPECTOR_VIRTUAL_PLAYER_BUFFER_REPLACEMENT_CONTRACT_OK")

-- Interrupted and malformed steps must leave a step-level failure event in the report.
local original_scheduler_for_stop = player.DoTaskInTime
local pending_task
player.DoTaskInTime = function(_, _delay, callback)
    pending_task = callback
end
local stopped_report
local stopped_controller = VirtualPlayer.new(player, {
    on_finished = function(report) stopped_report = report end,
})
assert(stopped_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "action", action = "CHOP" } },
}))
assert(stopped_controller.running == true and type(pending_task) == "function")
assert(stopped_controller:Stop("contract cancellation"))
assert(stopped_report ~= nil and stopped_report.outcome == "failed")
assert(stopped_report.results[2].status == "failed")
assert(stopped_report.results[2].detail == "contract cancellation")
pending_task()
assert(stopped_controller.running == false)
player.DoTaskInTime = original_scheduler_for_stop

local malformed_step_report
local malformed_step_controller = VirtualPlayer.new(player, {
    on_finished = function(report) malformed_step_report = report end,
})
assert(malformed_step_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { "not-an-object" },
}))
assert(malformed_step_report ~= nil and malformed_step_report.outcome == "failed")assert(malformed_step_report.results[1].kind == "invalid")
assert(malformed_step_report.results[1].status == "failed")
local multi_verification_report
local multi_verification
multi_verification = VirtualPlayer.new(player, {
    allowed_prefabs = { "cutgrass" },
    send_rpc = function(kind, request_id, prefab, count)
        multi_verification:OnRPCResult(request_id, true, "spawned " .. tostring(count) .. " " .. tostring(prefab))
    end,
    on_finished = function(report) multi_verification_report = report end,
})
assert(multi_verification:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = {
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 2 }, verifies_steps = { 1, 2 } },
    },
}))
assert(multi_verification_report ~= nil and multi_verification_report.outcome == "passed")
assert(multi_verification_report.steps_verified == 2 and multi_verification_report.steps_unverified == 0)
assert(multi_verification_report.verification_assertions_passed == 1,
    "one assertion linked to two steps must count as one verification assertion")
print("MODXPECTOR_VIRTUAL_PLAYER_MULTI_STEP_VERIFICATION_CONTRACT_OK")

print("MODXPECTOR_VIRTUAL_PLAYER_STEP_FAILURE_EVIDENCE_CONTRACT_OK")


-- EQUIP and UNEQUIP must use the allowlisted carried item as BufferedAction.invobject,
-- then require an explicit equipment-state postcondition before the run can pass.
ACTIONS.EQUIP = { name = "EQUIP" }
ACTIONS.UNEQUIP = { name = "UNEQUIP" }
local equipment_item = { prefab = "axe" }
local equipped_item
local equipment_player
equipment_player = {
    prefab = "wilson",
    IsValid = function() return true end,
    ListenForEvent = function() end,
    DoTaskInTime = function(_, delay, callback)
        current_time = current_time + (delay or 0)
        callback()
    end,
    GetBufferedAction = function() return nil end,
    components = {
        playercontroller = {
            DoAction = function(_, action)
                if action.action == ACTIONS.EQUIP then
                    assert(action.invobject == equipment_item, "EQUIP must receive the selected carried item")
                    equipped_item = action.invobject
                elseif action.action == ACTIONS.UNEQUIP then
                    assert(action.invobject == equipment_item, "UNEQUIP must receive the selected equipped item")
                    equipped_item = nil
                end
            end,
        },
    },
    replica = {
        inventory = {
            FindItem = function(_, predicate)
                return predicate(equipment_item) and equipment_item or nil
            end,
            GetEquippedItem = function(_, slot)
                return slot == EQUIPSLOTS.HANDS and equipped_item or nil
            end,
        },
    },
}
local equipment_report
local equipment_controller = VirtualPlayer.new(equipment_player, {
    allowed_prefabs = { "axe" },
    on_finished = function(report) equipment_report = report end,
})
local equipment_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = {
        { kind = "action", action = "EQUIP", invobject = "axe" },
        { kind = "assert", assertion = { kind = "player_equipped", slot = "HANDS", prefab = "axe" }, verifies_step = 1 },
        { kind = "action", action = "UNEQUIP", invobject = "axe" },
        { kind = "assert", assertion = { kind = "player_equipped", slot = "HANDS", prefab = "axe", expected = false }, verifies_step = 3 },
    },
}
assert(equipment_controller:Start(equipment_plan))
assert(equipment_report ~= nil and equipment_report.outcome == "passed")
assert(equipment_report.steps_verified == 2 and equipment_report.steps_unverified == 0)
assert(equipment_report.assertions_total == 2 and equipment_report.assertions_passed == 2)
assert(equipment_report.verification_assertions_passed == 2)
assert(equipped_item == nil, "UNEQUIP must leave the hands slot empty in this contract")
print("MODXPECTOR_VIRTUAL_PLAYER_EQUIP_UNEQUIP_CONTRACT_OK")


-- The first AI profile must move through the real Virtual Player action path
-- and verify arrival against the exact entity reference captured by WALKTO.
local walk_target = {
    prefab = "grass",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 3, 0, 4 end },
}
local walk_x, walk_z = 0, 0
local walk_player = {
    prefab = "wilson",
    IsValid = function() return true end,
    ListenForEvent = function() end,
    Transform = { GetWorldPosition = function() return walk_x, 0, walk_z end },
    GetBufferedAction = function() return nil end,
    DoTaskInTime = function(_, delay, callback)
        current_time = current_time + (delay or 0)
        callback()
    end,
    components = {
        playercontroller = {
            DoAction = function(_, action)
                assert(action.action == ACTIONS.WALKTO)
                assert(action.target == walk_target)
                local target_x, _, target_z = walk_target.Transform.GetWorldPosition()
                walk_x, walk_z = target_x, target_z
            end,
        },
    },
}
local original_find_entities = TheSim.FindEntities
TheSim.FindEntities = function() return { walk_target } end
local walk_report
local walk_controller = VirtualPlayer.new(walk_player, {
    allowed_actions = { "WALKTO" },
    allowed_prefabs = { "grass" },
    on_finished = function(report) walk_report = report end,
})
assert(walk_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "ai-walkto-safe-profile",
    allowed_actions = { "WALKTO" },
    allowed_prefabs = { "grass" },
    steps = {
        { kind = "action", action = "WALKTO", target = { prefab = "grass", radius = 12 }, target_required = true },
        { kind = "assert", assertion = { kind = "player_near_target", target_step = 1, radius = 4 }, verifies_step = 1 },
    },
}))
assert(walk_report ~= nil and walk_report.outcome == "passed")
assert(walk_report.steps_verified == 1 and walk_report.steps_unverified == 0)
assert(walk_report.assertions_total == 1 and walk_report.assertions_passed == 1)
assert(walk_x == 3 and walk_z == 4)
TheSim.FindEntities = original_find_entities
print("MODXPECTOR_VIRTUAL_PLAYER_WALKTO_AI_PROFILE_CONTRACT_OK")

-- Stopping or timing out must clear the Virtual Player's own buffered action.
local cancel_counts = { stop = 0, clear = 0, entity_clear = 0 }
local cancel_action = { action = ACTIONS.CHOP }
local cancel_current_action = cancel_action
local cancel_locomotor = {
    bufferedaction = cancel_action,
    Stop = function() cancel_counts.stop = cancel_counts.stop + 1 end,
    Clear = function(self)
        cancel_counts.clear = cancel_counts.clear + 1
        self.bufferedaction = nil
    end,
}
local cancel_player = {
    prefab = "wilson",
    components = { locomotor = cancel_locomotor, playercontroller = { DoAction = function() end } },
    IsValid = function() return true end,
    GetBufferedAction = function() return cancel_locomotor.bufferedaction end,
    DoTaskInTime = function() end, -- retain the scheduled tick; this test stops before it runs
}
local cancel_report
local cancel_controller = VirtualPlayer.new(cancel_player, {
    on_finished = function(report) cancel_report = report end,
})
assert(cancel_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "cancel-owned-action",
    steps = { { kind = "action", action = "CHOP", timeout = 5 } },
}))
cancel_controller.index = 1
cancel_controller.active = { action = cancel_action, step = { kind = "action", action = "CHOP" } }
assert(cancel_controller:Stop("user requested cancellation"))
assert(cancel_counts.stop == 1 and cancel_counts.clear == 1 and cancel_counts.entity_clear == 0,
    "cancellation must stop locomotion and clear only the matching locomotor action")
assert(cancel_locomotor.bufferedaction == nil and cancel_report ~= nil and cancel_report.running == false)
assert(cancel_report.active_action_cancellation == "cancelled",
    "the final report must distinguish a confirmed cancellation from a generic stop")

-- A cleanup API that returns normally but leaves the action buffered is not a confirmed cancellation.
local noop_action = { action = ACTIONS.CHOP }
local noop_locomotor = {
    bufferedaction = noop_action,
    Stop = function() end,
    Clear = function() return true end, -- deliberately does not clear bufferedaction
}
local noop_player = {
    prefab = "wilson",
    components = { locomotor = noop_locomotor, playercontroller = { DoAction = function() end } },
    IsValid = function() return true end,
    GetBufferedAction = function() return noop_locomotor.bufferedaction end,
    DoTaskInTime = function() end,
}
local noop_controller = VirtualPlayer.new(noop_player, {})
assert(noop_controller:Start({
    schema = "modxpector/test-plan/v1", enabled = true, run_id = "cancel-noop-clear",
    steps = { { kind = "action", action = "CHOP", timeout = 5 } },
}))
noop_controller.index = 1
noop_controller.active = { action = noop_action, step = { kind = "action", action = "CHOP" } }
assert(noop_controller:Stop("verify no-op clear"))
assert(noop_controller:GetReport().active_action_cancellation == "not_cancelled",
    "a no-op Clear must not be reported as a confirmed cancellation")
assert(noop_locomotor.bufferedaction == noop_action,
    "the cancellation check must not claim that an action was cleared when it remains buffered")

-- Entity-side buffered actions must be cleared without touching an unrelated locomotor action.
cancel_counts = { stop = 0, clear = 0, entity_clear = 0 }
local entity_action = { action = ACTIONS.CHOP }
local entity_player = {
    prefab = "wilson",
    bufferedaction = entity_action,
    components = {
        locomotor = {
            bufferedaction = nil,
            Stop = function() cancel_counts.stop = cancel_counts.stop + 1 end,
            Clear = function() cancel_counts.clear = cancel_counts.clear + 1 end,
        },
        playercontroller = { DoAction = function() end },    },
    IsValid = function() return true end,
    GetBufferedAction = function(self) return self.bufferedaction end,
    ClearBufferedAction = function(self)
        cancel_counts.entity_clear = cancel_counts.entity_clear + 1
        self.bufferedaction = nil
    end,
    DoTaskInTime = function() end,
}
local entity_controller = VirtualPlayer.new(entity_player, {})
assert(entity_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "cancel-entity-action",
    steps = { { kind = "action", action = "CHOP", timeout = 5 } },
}))
entity_controller.index = 1
entity_controller.active = { action = entity_action, step = { kind = "action", action = "CHOP" } }
assert(entity_controller:Stop("user requested cancellation"))
assert(cancel_counts.stop == 0 and cancel_counts.clear == 0 and cancel_counts.entity_clear == 1)
assert(entity_player.bufferedaction == nil)

-- If another system replaces the buffered action, stopping ModXpector must not cancel it.
cancel_counts = { stop = 0, clear = 0, entity_clear = 0 }
local unrelated_action = { action = ACTIONS.PICKUP }
local unrelated_player = {
    prefab = "wilson",
    bufferedaction = unrelated_action,
    components = {
        locomotor = {
            bufferedaction = nil,
            Stop = function() cancel_counts.stop = cancel_counts.stop + 1 end,
            Clear = function() cancel_counts.clear = cancel_counts.clear + 1 end,
        },
        playercontroller = { DoAction = function() end },
    },
    IsValid = function() return true end,
    GetBufferedAction = function(self) return self.bufferedaction end,
    ClearBufferedAction = function(self)
        cancel_counts.entity_clear = cancel_counts.entity_clear + 1
        self.bufferedaction = nil
    end,
    DoTaskInTime = function() end,
}
local unrelated_controller = VirtualPlayer.new(unrelated_player, {})
assert(unrelated_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "cancel-does-not-touch-user-action",
    steps = { { kind = "action", action = "CHOP", timeout = 5 } },
}))
unrelated_controller.index = 1
unrelated_controller.active = { action = cancel_action, step = { kind = "action", action = "CHOP" } }
assert(unrelated_controller:Stop("user requested cancellation"))
assert(cancel_counts.stop == 0 and cancel_counts.clear == 0 and cancel_counts.entity_clear == 0,
    "cancellation must leave an unrelated replacement action untouched")
assert(unrelated_player.bufferedaction == unrelated_action)
assert(unrelated_controller:GetReport().active_action_cancellation == "not_cancelled")
print("MODXPECTOR_VIRTUAL_PLAYER_CANCEL_ACTION_CONTRACT_OK")

-- A stalled WALKTO requests one fresh native path search, then fails safely if still stuck.
-- Earlier contracts deliberately replace FindEntities with an empty result; isolate this scenario.
local path_original_find_entities = TheSim.FindEntities
local path_target = {
    prefab = "tree",
    IsValid = function() return true end,
    HasTag = function() return true end,
    Transform = { GetWorldPosition = function() return 3, 0, 0 end },
}
TheSim.FindEntities = function() return { path_target } end
local path_tasks = {}
local path_reset_count, path_find_count, path_stop_count = 0, 0, 0
local path_player_position = 0
local path_locomotor = {
    bufferedaction = nil,
    dest = { IsValid = function() return true end },
    lastdesttile = "stale_destination_tile",
    ResetPath = function(self)
        path_reset_count = path_reset_count + 1
        self.path = nil
    end,
    FindPath = function() path_find_count = path_find_count + 1 end,
    Stop = function() path_stop_count = path_stop_count + 1 end,
    Clear = function(self)
        self.bufferedaction = nil
        self.dest = nil
    end,
}
local path_player = {
    prefab = "wilson",
    components = {
        locomotor = path_locomotor,
        playercontroller = {
            DoAction = function(_, action) path_locomotor.bufferedaction = action end,
        },
    },
    Transform = { GetWorldPosition = function() return path_player_position, 0, 0 end },
    IsValid = function() return true end,
    GetBufferedAction = function() return path_locomotor.bufferedaction end,
    DoTaskInTime = function(_, delay, fn)
        path_tasks[#path_tasks + 1] = { due = current_time + delay, fn = fn }
    end,
}
local path_finished
local path_controller = VirtualPlayer.new(path_player, {
    allowed_actions = { "WALKTO" },
    allowed_prefabs = { "tree" },
    stuck_timeout = 2,
    max_path_replan_attempts = 1,
    on_finished = function(report) path_finished = report end,
})
path_controller.poll_interval = 1
current_time = 100
assert(path_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "bounded-walkto-replan",
    allowed_prefabs = { "tree" },
    steps = {
        { kind = "action", action = "WALKTO", target = { prefab = "tree", radius = 12 }, target_required = true, timeout = 20 },
    },
}))
local function run_next_path_task()
    table.sort(path_tasks, function(a, b) return a.due < b.due end)
    local task = table.remove(path_tasks, 1)
    assert(task ~= nil, "expected a scheduled Virtual Player poll")
    current_time = task.due
    task.fn()
end
run_next_path_task() -- begin movement tracking
run_next_path_task() -- no progress yet
run_next_path_task() -- one ResetPath + FindPath request
assert(path_reset_count == 1 and path_find_count == 1,
    "stalled WALKTO must request exactly one native path refresh")
assert(path_locomotor.lastdesttile == nil,
    "path recovery must clear the cached destination tile before FindPath")
run_next_path_task() -- wait after replan
run_next_path_task() -- bounded recovery exhausted
assert(path_finished ~= nil and path_finished.outcome == "failed")
assert(path_finished.path_replan_requests == 1)
assert(path_finished.active_action_cancellation == "cancelled")
assert(path_locomotor.bufferedaction == nil and path_stop_count == 1,
    "a still-stuck WALKTO must cancel its own action after the bounded replan")
assert(path_controller.running == false)
TheSim.FindEntities = path_original_find_entities
print("MODXPECTOR_VIRTUAL_PLAYER_BOUNDED_PATH_REPLAN_CONTRACT_OK")

-- Transfer postconditions must prove item-count deltas on both sides of STORE.
local carried_count, chest_count = 4, 0
local transfer_target_valid = true
local transfer_target = {
    prefab = "treasurechest",
    IsValid = function() return transfer_target_valid end,
    replica = { container = {
        IsOpenedBy = function() return true end,
        Has = function(_, prefab) return chest_count >= 1, chest_count end,
    } },
}
local transfer_player = {
    prefab = "wilson",
    IsValid = function() return true end,
    replica = { inventory = {
        Has = function(_, prefab) return carried_count >= 1, carried_count end,
        GetEquippedItem = function() return nil end,
    } },
}
local transfer_controller = VirtualPlayer.new(transfer_player, {
    allowed_prefabs = { "cutgrass" },
})
transfer_controller.queue = {
    { kind = "action", action = "STORE", target_required = true },
    { kind = "assert", assertion = {
        kind = "player_inventory_item_count_decreased", prefab = "cutgrass", target_step = 1, count = 1,
    }, verifies_step = 1 },
    { kind = "assert", assertion = {
        kind = "container_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
    }, verifies_step = 1 },
}
transfer_controller.index = 1
transfer_controller.step_targets = {}
transfer_controller.target_death_events = {}
transfer_controller.target_death_callbacks = {}
transfer_controller:_capture_step_target(1, transfer_target)
transfer_controller:_capture_step_transfer_baseline(1, transfer_target)
carried_count, chest_count = 3, 1 -- one item moved: valid partial transfer
transfer_controller.index = 2
local store_player_delta = transfer_controller:_evaluate_assertion({
    kind = "player_inventory_item_count_decreased", prefab = "cutgrass", target_step = 1, count = 1,
})
local store_container_delta = transfer_controller:_evaluate_assertion({
    kind = "container_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
})
assert(store_player_delta.passed and store_container_delta.passed,
    "STORE must verify both inventory decrease and container increase, including partial transfer")

-- A one-sided change must not be reported as a successful transfer.
carried_count, chest_count = 4, 0
transfer_controller.index = 1
transfer_controller:_capture_step_transfer_baseline(1, transfer_target)
carried_count = 3
transfer_controller.index = 2
local store_one_sided = transfer_controller:_evaluate_assertion({
    kind = "container_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
})
assert(not store_one_sided.passed,
    "a player inventory decrease without a matching container increase must fail")

-- A removed target or unavailable/invalid replica must fail closed.
carried_count, chest_count = 4, 0
transfer_controller.index = 1
transfer_target_valid = true
transfer_controller:_capture_step_transfer_baseline(1, transfer_target)
transfer_target_valid = false
transfer_controller.index = 2
local removed_transfer_target_ok = pcall(function()
    transfer_controller:_evaluate_assertion({
        kind = "container_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
    })
end)
assert(not removed_transfer_target_ok, "STORE verification must reject a removed target")

transfer_target_valid = true
local missing_container_target = {
    IsValid = function() return true end,
    replica = {},
}
transfer_controller.index = 1
local missing_container_baseline_ok = pcall(function()
    transfer_controller:_capture_step_transfer_baseline(1, missing_container_target)
end)
assert(not missing_container_baseline_ok, "STORE baseline must fail closed without a container replica")

local invalid_count_target = {
    IsValid = function() return true end,
    replica = { container = { Has = function() return true, 0 / 0 end } },
}
transfer_controller.index = 1
local invalid_count_baseline_ok = pcall(function()
    transfer_controller:_capture_step_transfer_baseline(1, invalid_count_target)
end)
assert(not invalid_count_baseline_ok, "STORE baseline must reject non-finite container counts")

-- TAKEITEM must increase the carried inventory count; target state is a separate proof.
local held_count, holder_has_item = 2, true
local holder_target = {
    prefab = "birdcage",
    IsValid = function() return true end,
    HasTag = function(_, tag) return tag == "inventoryitemholder_take" and holder_has_item end,
}
local holder_player = {
    prefab = "wilson",
    IsValid = function() return true end,
    replica = { inventory = {
        Has = function(_, prefab) return held_count >= 1, held_count end,
        GetEquippedItem = function() return nil end,
    } },
}
local take_controller = VirtualPlayer.new(holder_player, { allowed_prefabs = { "cutgrass" } })
take_controller.queue = {
    { kind = "action", action = "TAKEITEM", target_required = true },
    { kind = "assert", assertion = {
        kind = "player_inventory_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
    }, verifies_step = 1 },
}
take_controller.index = 1
take_controller.step_targets = {}
take_controller.target_death_events = {}
take_controller.target_death_callbacks = {}
take_controller:_capture_step_target(1, holder_target)
take_controller:_capture_step_transfer_baseline(1, holder_target)
held_count = 3
take_controller.index = 2
local take_delta = take_controller:_evaluate_assertion({
    kind = "player_inventory_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
})
assert(take_delta.passed, "TAKEITEM must prove a real increase in carried inventory")

held_count = 2
holder_has_item = true
take_controller.index = 1
take_controller:_capture_step_transfer_baseline(1, holder_target)
take_controller.index = 2
local take_no_change = take_controller:_evaluate_assertion({
    kind = "player_inventory_item_count_increased", prefab = "cutgrass", target_step = 1, count = 1,
})
local take_holder_unchanged = take_controller:_evaluate_assertion({
    kind = "target_has_tag", target_step = 1, tag = "inventoryitemholder_take", expected = false,
})
assert(not take_no_change.passed and not take_holder_unchanged.passed,
    "TAKEITEM must fail when neither inventory nor holder state changes")


holder_has_item = false
local holder_state = take_controller:_evaluate_assertion({
    kind = "target_has_tag", target_step = 1, tag = "inventoryitemholder_take", expected = false,
})
assert(holder_state.passed,
    "TAKEITEM must also verify that the holder no longer advertises a takeable item")


local closed_transfer_target = {
    IsValid = function() return true end,
    replica = { container = {
        IsOpenedBy = function() return false end,
        Has = function() return true, 99 end,
    } },
}
transfer_controller.index = 1
local closed_container_baseline_ok = pcall(function()
    transfer_controller:_capture_step_transfer_baseline(1, closed_transfer_target)
end)
assert(not closed_container_baseline_ok,
    "STORE baseline must reject closed containers because their replica may report a false zero")


-- TAKEITEM/TAKESINGLEITEM are fail-closed until the exact held item can be identified
-- and its transfer into the player's inventory can be independently verified.
for _, blocked_action in ipairs({ "TAKEITEM", "TAKESINGLEITEM" }) do
    local submitted_actions = 0
    local blocked_report
    local blocked_player = {
        prefab = "wilson",
        IsValid = function() return true end,
        components = {
            playercontroller = {
                DoAction = function() submitted_actions = submitted_actions + 1 end,
            },
        },
    }
    local blocked_controller = VirtualPlayer.new(blocked_player, {
        on_finished = function(report) blocked_report = report end,
    })
    assert(blocked_controller:Start({
        schema = "modxpector/test-plan/v1",
        enabled = true,
        run_id = "blocked-" .. blocked_action,
        steps = {
            { kind = "action", action = blocked_action, target_required = true },
        },
    }))
    assert(submitted_actions == 0,
        blocked_action .. " must not reach PlayerController before identity-safe oracles exist")
    assert(blocked_report ~= nil and blocked_report.outcome == "inconclusive",
        blocked_action .. " must be reported as inconclusive, not passed or completed")
    assert(blocked_report.run_failed == nil or blocked_report.outcome == "inconclusive")
end
print("MODXPECTOR_VIRTUAL_PLAYER_TAKEITEM_FAIL_CLOSED_CONTRACT_OK")


-- STORE remains fail-closed: matching prefab count deltas cannot prove item identity.
local store_submissions = 0
local store_report
local store_player = {
    prefab = "wilson",
    IsValid = function() return true end,
    components = {
        playercontroller = {
            DoAction = function() store_submissions = store_submissions + 1 end,
        },
    },
}
local store_controller = VirtualPlayer.new(store_player, {
    on_finished = function(report) store_report = report end,
})
assert(store_controller:Start({
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "blocked-STORE-identity",
    steps = {
        { kind = "action", action = "STORE", target_required = true },
    },
}))
assert(store_submissions == 0,
    "STORE must not reach PlayerController while verification relies only on aggregate prefab deltas")
assert(store_report ~= nil and store_report.outcome == "inconclusive",
    "STORE identity gap must be reported as inconclusive")
-- A failed observer cleanup must abort later steps rather than attribute later events to PICKUP.
local cleanup_finished
local cleanup_original_find_entities = TheSim.FindEntities
TheSim.FindEntities = function() return { pickup_target } end
local original_remove_event_callback = player.RemoveEventCallback
player.RemoveEventCallback = function()
    error("synthetic listener cleanup failure")
end
local cleanup_controller = VirtualPlayer.new(player, {
    allowed_actions = { "MOD_ACTION" },
    allowed_prefabs = { "cutgrass" },
    on_finished = function(report) cleanup_finished = report end,
})
local cleanup_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "live-vp-observer-cleanup-failure",
    steps = {
        { kind = "action", action = "PICKUP", target = { prefab = "cutgrass" }, target_required = true },
        { kind = "assert", assertion = {
            kind = "pickup_target_collected", prefab = "cutgrass", target_step = 1,
        }, verifies_step = 1 },
        { kind = "wait", seconds = 0 },
    },
}
assert(cleanup_controller:Start(cleanup_plan))
assert(cleanup_finished ~= nil and cleanup_finished.outcome == "inconclusive",
    "pending observer cleanup must make the run inconclusive")
assert(cleanup_finished.step_event_observer_cleanup_pending == true
    and cleanup_finished.player_onremove_cleanup_pending == true,
    "the report must expose pending observer and player listener cleanup")
assert(cleanup_finished.results[#cleanup_finished.results - 1].status == "inconclusive",
    "the PICKUP step must be inconclusive when its observer listeners remain")
assert(cleanup_finished.results[#cleanup_finished.results].status == "failed",
    "the run must fail closed rather than execute subsequent steps")
assert(cleanup_controller.active_step_event_observer ~= nil,
    "the observer recovery handle must be retained while cleanup is pending")
player.RemoveEventCallback = original_remove_event_callback
TheSim.FindEntities = cleanup_original_find_entities
local recovered_observer = cleanup_controller:_stop_step_event_observer()
assert(recovered_observer ~= nil and recovered_observer.cleanup_complete == true,
    "pending observer listeners must remain recoverable after a transient cleanup failure")
assert(cleanup_controller:_cleanup_player_listener() == true,
    "the player onremove listener must also be recoverable")
assert(player:ListenerCount("itemget") == 0
    and player:ListenerCount("itemlose") == 0
    and player:ListenerCount("onremove") == 0,
    "all recovered listeners must be removed")
assert(pickup_target:ListenerCount("death") == 0,
    "the target death listener must also be removed after the run")

-- Target listener cleanup failures must remain visible and recoverable.
cleanup_finished = nil
original_remove_event_callback = pickup_target.RemoveEventCallback
pickup_target.RemoveEventCallback = function()
    error("synthetic target listener cleanup failure")
end
cleanup_controller = VirtualPlayer.new(player, {
    on_finished = function(report) cleanup_finished = report end,
})
cleanup_controller.step_targets = {}
cleanup_controller.target_death_events = {}
cleanup_controller.target_death_callbacks = {}
cleanup_controller.queue = {}
cleanup_controller.index = 0
cleanup_controller.run_id = "live-vp-target-listener-cleanup-failure"
cleanup_controller.started_at = GetTime()
cleanup_controller:_capture_step_target(1, pickup_target)
assert(pickup_target:ListenerCount("death") == 1,
    "the synthetic target must register one death listener")
cleanup_controller:_finish(true, "synthetic target cleanup")
assert(cleanup_finished ~= nil and cleanup_finished.outcome == "inconclusive",
    "target listener cleanup failure must make the run inconclusive")
assert(cleanup_finished.target_listener_cleanup_pending == true,
    "the final report must expose pending target listener cleanup")
assert(next(cleanup_controller.target_death_callbacks) ~= nil
    and pickup_target:ListenerCount("death") == 1,
    "the target callback handle must be retained while cleanup is pending")
assert(not pcall(function() cleanup_controller:Start(cleanup_plan) end),
    "a new run must not discard a previous target listener cleanup handle")
pickup_target.RemoveEventCallback = original_remove_event_callback
assert(cleanup_controller:_cleanup_target_listeners() == true,
    "target listener cleanup must be recoverable after a transient failure")
assert(cleanup_controller.target_listener_cleanup_pending == false
    and pickup_target:ListenerCount("death") == 0,
    "recovered target listener cleanup must remove the listener")


do
-- Isolated player onremove cleanup failure: no PICKUP and no step observer.
local isolated_player_report
local isolated_player_controller = VirtualPlayer.new(player, {
    on_finished = function(report) isolated_player_report = report end,
})
assert(isolated_player_controller:_bind_events() == true)
assert(player:ListenerCount("onremove") == 1)
local isolated_original_remove = player.RemoveEventCallback
player.RemoveEventCallback = function(self, event, callback, source)
    if event == "onremove" then error("isolated player listener cleanup failure") end
    return isolated_original_remove(self, event, callback, source)
end
isolated_player_controller.queue = {}
isolated_player_controller.index = 0
isolated_player_controller.started_at = GetTime()
isolated_player_controller:_finish(true, "isolated player listener cleanup")
assert(isolated_player_report ~= nil and isolated_player_report.outcome == "inconclusive",
    "an isolated player onremove cleanup failure must make the run inconclusive")
assert(isolated_player_report.player_onremove_cleanup_pending == true
    and isolated_player_controller.player_onremove_callback ~= nil
    and isolated_player_controller.player_onremove_owner == player,
    "failed player cleanup must retain the callback and original owner")
local no_pickup_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    steps = { { kind = "wait", seconds = 0 } },
}
assert(not pcall(function() isolated_player_controller:Start(no_pickup_plan) end),
    "a new run must be blocked while the player onremove listener remains pending")
player.RemoveEventCallback = isolated_original_remove
assert(isolated_player_controller:_cleanup_player_listener() == true,
    "player listener cleanup must be recoverable after restoring the removal API")
assert(player:ListenerCount("onremove") == 0
    and isolated_player_controller.player_onremove_cleanup_verified == true,
    "observable listener absence must be verified after recovery")

end

do
-- A removal call that returns normally but leaves the callback is not cleanup success.
local unverified_player_report
local unverified_player_controller = VirtualPlayer.new(player, {
    on_finished = function(report) unverified_player_report = report end,
})
assert(unverified_player_controller:_bind_events() == true)
local no_op_remove = player.RemoveEventCallback
player.RemoveEventCallback = function(self, event, callback, source)
    if event == "onremove" then return end
    return no_op_remove(self, event, callback, source)
end
unverified_player_controller.queue = {}
unverified_player_controller.index = 0
unverified_player_controller.started_at = GetTime()
unverified_player_controller:_finish(true, "no-op listener removal")
assert(unverified_player_report ~= nil and unverified_player_report.outcome == "inconclusive"
    and unverified_player_report.player_onremove_cleanup_pending == true,
    "a no-error removal call must not be accepted when the listener is still observable")
player.RemoveEventCallback = no_op_remove
assert(unverified_player_controller:_cleanup_player_listener() == true
    and player:ListenerCount("onremove") == 0,
    "the no-op removal case must remain recoverable")


end

do
-- A target RemoveEventCallback call that leaves the listener observable is still pending.
local target_noop_report
local target_remove_original = pickup_target.RemoveEventCallback
local target_noop_controller = VirtualPlayer.new(player, {
    on_finished = function(report) target_noop_report = report end,
})
target_noop_controller.step_targets = {}
target_noop_controller.target_death_events = {}
target_noop_controller.target_death_callbacks = {}
target_noop_controller.queue = {}
target_noop_controller.index = 0
target_noop_controller.run_id = "live-vp-target-listener-noop-removal"
target_noop_controller.started_at = GetTime()
target_noop_controller:_capture_step_target(1, pickup_target)
pickup_target.RemoveEventCallback = function() return end
target_noop_controller:_finish(true, "target no-op listener removal")
assert(target_noop_report ~= nil and target_noop_report.outcome == "inconclusive"
    and target_noop_report.target_listener_cleanup_pending == true,
    "a no-error target removal call must not pass while the listener remains observable")
assert(next(target_noop_controller.target_death_callbacks) ~= nil,
    "the target listener callback must be retained after an unverified no-op removal")
pickup_target.RemoveEventCallback = target_remove_original
assert(target_noop_controller:_cleanup_target_listeners() == true
    and target_noop_controller.target_listener_cleanup_verified == true
    and pickup_target:ListenerCount("death") == 0,
    "target listener cleanup must recover and verify actual removal")

end

print("MODXPECTOR_VIRTUAL_PLAYER_STORE_FAIL_CLOSED_CONTRACT_OK")
