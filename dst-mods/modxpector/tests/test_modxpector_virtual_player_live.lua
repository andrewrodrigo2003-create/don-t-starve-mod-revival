-- luacheck: globals ACTIONS BufferedAction Vector3 GetTime GetValidRecipe EQUIPSLOTS TheSim
local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

ACTIONS = {
    CHOP = { name = "CHOP" }, ATTACK = { name = "ATTACK" },
    WALKTO = { name = "WALKTO" }, MOD_ACTION = { name = "MOD_ACTION" },
    PICKUP = { name = "PICKUP" },
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
local open_container = {
    replica = {
        container = {
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
        end
    end } },
    replica = {
        inventory = {
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
                local found = prefab == "cutgrass" and (player.picked_up and 3 or 2) or 0
                return found >= count, found
            end,
            GetOpenContainers = function() return { [open_container] = true } end,
            GetOverflowContainer = function() return nil end,
            GetEquippedItem = function(_, slot)
                return slot == "hands" and { prefab = "axe" } or nil
            end,
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
    ListenForEvent = function() end,
    DoTaskInTime = function(_, delay, fn) current_time = current_time + (delay or 0); fn() end,
    GetBufferedAction = function() return nil end,
}
local structure_target = {
    prefab = "structure",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 2, 0, 3 end },
}
local pickup_target = {
    prefab = "cutgrass",
    IsValid = function() return true end,
    HasTag = function() return false end,
    Transform = { GetWorldPosition = function() return 1, 0, 0 end },
}
TheSim.FindEntities = function()
    local found = { target, pickup_target }
    if player ~= nil and player.placed_recipe ~= nil then found[#found + 1] = structure_target end
    return found
end
local VirtualPlayer = require("modxpector/virtual_player_client")
local finished
local controller
controller = VirtualPlayer.new(player, {
    allowed_actions = { "MOD_ACTION" },
    allowed_prefabs = { "cutgrass", "axe", "tree", "structure", "goldnugget" },
    allowed_recipes = { "axe", "structure" },
    send_rpc = function(kind, request_id, value, count, _x, _z)
        if kind == "unlock_recipe" then
            assert(value == "axe")
            controller:OnRPCResult(request_id, true, "unlocked recipe axe")
        else
            assert(kind == "spawn_item" and value == "cutgrass" and count == 2)
            controller:OnRPCResult(request_id, true, "spawned test items")
        end
    end,
    on_finished = function(report) finished = report end,
})
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
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "axe", count = 1 }, verifies_step = 5 },
        { kind = "assert", assertion = { kind = "target_exists", target = { prefab = "structure" } }, verifies_step = 6 },
        { kind = "assert", assertion = { kind = "player_equipped", slot = "HANDS", prefab = "axe" } },
        { kind = "assert", assertion = { kind = "player_near_target", target = { prefab = "tree" }, radius = 5 } },
        { kind = "assert", assertion = { kind = "target_exists", target = { prefab = "tree" } } },
        { kind = "assert", assertion = { kind = "target_health_lte", target = { prefab = "tree" }, value = 30 }, verifies_step = 1 },
        { kind = "assert", assertion = { kind = "target_dead", target = { prefab = "tree" }, expected = false } },
        { kind = "assert", assertion = { kind = "target_has_tag", target = { prefab = "tree" }, tag = "workable" } },
        { kind = "action", action = "PICKUP", target = { prefab = "cutgrass" }, target_required = true },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 3 }, verifies_step = 24 },
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
        assert(result.target_prefab == "cutgrass" and result.recipe == nil)
        saw_spawn_metadata = true
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
TheSim.FindEntities = function() return {} end
local removed_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" } })
assert(removed_result.actual == nil and removed_result.inconclusive == true and removed_result.passed == false,
    "a missing target without a death event must not be reported as confirmed dead")
assert(finished.results[#finished.results].status == "completed")

local target_ok, target_err = pcall(function() controller:ResolveTarget({ prefab = "modxpector_unapproved_test_prefab" }) end)
assert(not target_ok and string.find(tostring(target_err), "allowlist", 1, true))
local tag_only_ok = pcall(function() controller:ResolveTarget({ tag = "workable" }) end)
assert(not tag_only_ok)
local custom = controller:BuildAction({ action = "MOD_ACTION", invobject = "cutgrass" })
assert(custom.action == ACTIONS.MOD_ACTION and custom.invobject.prefab == "cutgrass")
local ok, err = pcall(function() controller:BuildAction({ action = "UNSAFE_EXEC" }) end)
assert(not ok and string.find(tostring(err), "not allowed", 1, true))
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
    schema = "modxpector/test-plan/v1",
    enabled = true,
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
assert(malformed_step_report ~= nil and malformed_step_report.outcome == "failed")
assert(malformed_step_report.results[1].kind == "invalid")
assert(malformed_step_report.results[1].status == "failed")
print("MODXPECTOR_VIRTUAL_PLAYER_STEP_FAILURE_EVIDENCE_CONTRACT_OK")
