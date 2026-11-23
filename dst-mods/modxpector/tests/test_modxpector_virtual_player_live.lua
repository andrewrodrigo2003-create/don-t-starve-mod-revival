-- luacheck: globals ACTIONS BufferedAction Vector3 GetTime GetValidRecipe EQUIPSLOTS TheSim
local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

ACTIONS = {
    CHOP = { name = "CHOP" }, ATTACK = { name = "ATTACK" },
    WALKTO = { name = "WALKTO" }, MOD_ACTION = { name = "MOD_ACTION" },
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

local player
player = {
    prefab = "wilson",
    components = { playercontroller = { DoAction = function(self, action) self.last_action = action end } },
    replica = {
        inventory = {
            FindItem = function(_, fn)
                local item = { prefab = "cutgrass" }
                return fn(item) and item or nil
            end,
            Has = function(_, prefab, count) return prefab == "cutgrass" and count <= 2 end,
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
            MakeRecipeFromMenu = function(_, recipe) player.crafted_recipe = recipe.name end,
            BufferBuild = function(self, recipe) self.buffered = self.buffered or {}; self.buffered[recipe] = true end,
            IsBuildBuffered = function(self, recipe) return self.buffered ~= nil and self.buffered[recipe] == true end,
            CanBuildAtPoint = function(_, point, _, rotation)
                return point.x == 2 and point.z == 3 and rotation == 0
            end,
            MakeRecipeAtPoint = function(_, recipe, point, rotation)
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
local VirtualPlayer = require("modxpector/virtual_player_client")
local finished
local controller
controller = VirtualPlayer.new(player, {
    allowed_actions = { "MOD_ACTION" },
    allowed_prefabs = { "cutgrass", "axe", "tree" },
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
    allowed_recipes = { "axe", "structure" },
    steps = {
        { kind = "action", action = "CHOP", timeout = 5 },
        { kind = "wait", seconds = 0 },
        { kind = "spawn_item", prefab = "cutgrass", count = 2 },
        { kind = "unlock_recipe", recipe = "axe" },
        { kind = "craft", recipe = "axe" },
        { kind = "craft_at_point", recipe = "structure", position = { x = 2, z = 3 }, rotation = 0 },
        { kind = "assert", assertion = { kind = "player_has_item", prefab = "cutgrass" } },
        { kind = "assert", assertion = { kind = "player_health_gte", value = 100 } },
        { kind = "assert", assertion = { kind = "player_hunger_gte", value = 70 } },
        { kind = "assert", assertion = { kind = "player_sanity_gte", value = 80 } },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 2 } },
        { kind = "assert", assertion = { kind = "player_equipped", slot = "HANDS", prefab = "axe" } },
        { kind = "assert", assertion = { kind = "player_near_target", target = { prefab = "tree" }, radius = 5 } },
        { kind = "assert", assertion = { kind = "target_exists", target = { prefab = "tree" } } },
        { kind = "assert", assertion = { kind = "target_health_lte", target = { prefab = "tree" }, value = 30 } },
        { kind = "assert", assertion = { kind = "target_dead", target = { prefab = "tree" }, expected = false } },
        { kind = "assert", assertion = { kind = "target_has_tag", target = { prefab = "tree" }, tag = "workable" } },
    },
}
assert(controller:Start(plan))
assert(finished ~= nil and finished.running == false)
assert(player.components.playercontroller.last_action.action == ACTIONS.CHOP)
assert(finished.results[1].status == "started")
assert(finished.results[2].status == "cleared_unverified")
assert(finished.assertions_total == 11 and finished.assertions_passed == 11)
assert(finished.outcome == "passed")
assert(player.crafted_recipe == "axe")
assert(player.placed_recipe ~= nil and player.placed_recipe.name == "structure")
assert(player.placed_recipe.point.x == 2 and player.placed_recipe.point.z == 3)
target.replica.health.GetCurrent = function() return 0 end
local dead_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" } })
assert(dead_result.actual == true and dead_result.passed == true)
target.replica.health.GetCurrent = function() return 25 end
local alive_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" }, expected = false })
assert(alive_result.actual == false and alive_result.passed == true)
TheSim.FindEntities = function() return {} end
local removed_result = controller:_evaluate_assertion({ kind = "target_dead", target = { prefab = "tree" } })
assert(removed_result.actual == true and removed_result.passed == true)
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
assert(player.crafted_recipe == "axe", "disallowed recipe must not be crafted")

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
assert(player.placed_recipe ~= nil and player.placed_recipe.name == "structure",
    "disallowed placer recipe must not be submitted again")
print("MODXPECTOR_CRAFT_RECIPE_ALLOWLIST_CONTRACT_OK")
