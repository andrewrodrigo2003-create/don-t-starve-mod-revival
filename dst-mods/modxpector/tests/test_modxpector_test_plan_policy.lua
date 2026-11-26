-- Shared test-plan policy: fail-closed action gates, loaded owner checks and exact suite binding.
local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

local Policy = require("modxpector/test_plan_policy")
local AI = require("modxpector/embedded_ai")

for _, action in ipairs({ "STORE", "TAKEITEM", "TAKESINGLEITEM" }) do
    assert(Policy.IsBlockedAction(action), action .. " must be globally blocked")
    assert(not Policy.IsServerActionAllowed(action), action .. " must be rejected by the Master policy")
    assert(not Policy.IsCommunityActionAllowed(action), action .. " must be rejected for community suites")
    assert(not Policy.IsClientActionAllowed(action, { [action] = true }),
        action .. " must not be enabled by a client plan allowlist")
end

assert(Policy.IsServerActionAllowed("ATTACK"), "internal laboratory action allowlist should retain ATTACK")
assert(Policy.IsServerActionAllowed("WALKTO"), "server policy should allow WALKTO")
assert(Policy.IsCommunityActionAllowed("WALKTO"), "community policy should allow WALKTO")
assert(Policy.IsCommunityActionAllowed("PICKUP"), "community policy should allow PICKUP")
assert(not Policy.IsCommunityActionAllowed("ATTACK"), "community policy must remain narrower than internal tests")
assert(Policy.IsClientActionAllowed("MOD_ACTION", { MOD_ACTION = true }),
    "client policy may retain an explicit internal test allowlist for non-blocked actions")

local loaded_snapshot = {
    capabilities = { loaded_mod_list = true },
    mods = {
        {
            id = "workshop-100",
            enabled = true, enabled_known = true,
            loaded = true, loaded_known = true, load_state = "loaded",
            metadata_available = true, server_enabled = true, server_enabled_known = true,
        },
    },
}
local loaded_ok = Policy.IsOwnerModConfirmedLoaded(loaded_snapshot, "workshop-100")
assert(loaded_ok, "confirmed server-loaded owner mod should pass")

local unknown_snapshot = {
    capabilities = { loaded_mod_list = false },
    mods = {
        {
            id = "workshop-100", enabled = true, enabled_known = true,
            loaded = false, loaded_known = false, load_state = "unknown",
            metadata_available = true, server_enabled = true, server_enabled_known = true,
        },
    },
}
local unknown_ok = Policy.IsOwnerModConfirmedLoaded(unknown_snapshot, "workshop-100")
assert(not unknown_ok, "unknown load state must never authorize suite execution")

local unloaded_snapshot = {
    capabilities = { loaded_mod_list = true },
    mods = {
        {
            id = "workshop-100", enabled = true, enabled_known = true,
            loaded = false, loaded_known = true, load_state = "enabled_not_observed_loaded",
            metadata_available = true, server_enabled = true, server_enabled_known = true,
        },
    },
}
local unloaded_ok = Policy.IsOwnerModConfirmedLoaded(unloaded_snapshot, "workshop-100")
assert(not unloaded_ok, "enabled but not observed loaded must be rejected")

local client_only_snapshot = {
    capabilities = { loaded_mod_list = true },
    mods = {
        {
            id = "workshop-100", enabled = true, enabled_known = true,
            loaded = true, loaded_known = true, load_state = "loaded",
            metadata_available = true, server_enabled = false, server_enabled_known = true,
        },
    },
}
local client_only_ok = Policy.IsOwnerModConfirmedLoaded(client_only_snapshot, "workshop-100")
assert(not client_only_ok, "client-only owner mods cannot authorize world-changing community suites")

local suite = {
    schema = "modxpector/test-suite/v1",
    id = "policy_grass_smoke",
    owner_mod_id = "workshop-100",
    title = "Policy grass smoke",
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "WALKTO" },
    scenarios = {
        {
            id = "approach_grass",
            title = "Approach grass",
            steps = {
                {
                    kind = "action", action = "WALKTO",
                    target = { prefab = "grass", radius = 12 }, target_required = true,
                },
                {
                    kind = "assert",
                    assertion = { kind = "player_near_target", target_step = 1, radius = 4 },
                    verifies_step = 1,
                },
            },
        },
    },
}
local suite_ok, normalized = AI.ValidateSuite(suite)
assert(suite_ok == true, "test fixture suite should validate")
local plan = AI.BuildVirtualPlayerPlan(normalized, "approach_grass", "policy_run_1")
assert(type(plan) == "table", "registered scenario should compile")
local valid_plan = Policy.ValidateCommunityPlan(plan, { normalized }, AI)
assert(valid_plan, "exact registered community plan should pass")

local forged_allowlist = AI.BuildVirtualPlayerPlan(normalized, "approach_grass", "policy_run_2")
forged_allowlist.allowed_prefabs = { "grass", "treasurechest" }
local forged_allowlist_ok = Policy.ValidateCommunityPlan(forged_allowlist, { normalized }, AI)
assert(not forged_allowlist_ok, "client cannot expand a registered suite prefab allowlist")

local forged_step = AI.BuildVirtualPlayerPlan(normalized, "approach_grass", "policy_run_3")
forged_step.steps[1].action = "PICKUP"
local forged_step_ok = Policy.ValidateCommunityPlan(forged_step, { normalized }, AI)
assert(not forged_step_ok, "client cannot alter the registered suite scenario steps")

local unregistered_ok = Policy.ValidateCommunityPlan(plan, {}, AI)
assert(not unregistered_ok, "Master must reject a suite not registered on the server")

local wrong_owner = AI.BuildVirtualPlayerPlan(normalized, "approach_grass", "policy_run_4")
wrong_owner.owner_mod_id = "workshop-200"
local wrong_owner_ok = Policy.ValidateCommunityPlan(wrong_owner, { normalized }, AI)
assert(not wrong_owner_ok, "suite plan owner must match the server-registered declaration")

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end
local modmain = read_file(ROOT .. "/dst-mods/modxpector/modmain.lua")
assert(modmain:find("TEST_PLAN_POLICY.IsServerActionAllowed", 1, true),
    "Master plan validation must use the shared server action policy")
assert(modmain:find("TEST_PLAN_POLICY.ValidateCommunityPlan", 1, true),
    "Master must compare incoming community plans with registered suite declarations")
assert(modmain:find("TEST_PLAN_POLICY.IsOwnerModConfirmedLoaded", 1, true),
    "Master must verify the owner mod is confirmed loaded")
local client = read_file(ROOT .. "/dst-mods/modxpector/scripts/modxpector/virtual_player_client.lua")
assert(client:find("TEST_PLAN_POLICY.IsClientActionAllowed", 1, true),
    "Virtual Player must use the shared client action policy")

print("ModXpector test-plan policy contracts passed")
