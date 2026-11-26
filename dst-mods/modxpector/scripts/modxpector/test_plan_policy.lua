-- Shared fail-closed policy for Virtual Player and Master-side plan validation.
-- Keep community actions narrower than internal laboratory actions.
local M = {}

local BLOCKED_ACTIONS = {
    STORE = true,
    TAKEITEM = true,
    TAKESINGLEITEM = true,
}

local SERVER_ACTION_ALLOWLIST = {
    ATTACK = true, CHOP = true, MINE = true, DIG = true, HAMMER = true,
    PICK = true, HARVEST = true, PICKUP = true, TILL = true, REPAIR = true,
    WALKTO = true, EAT = true, USEITEM = true, CASTAOE = true, CASTSPELL = true,
    RUMMAGE = true, DISMOUNT = true, MOUNT = true, TALKTO = true, DEPLOY = true,
    PLANT = true, EQUIP = true, UNEQUIP = true, GIVE = true, DROP = true,
    COOK = true, READ = true, SADDLE = true, FISH = true, CATCH = true,
    LIGHT = true, EXTINGUISH = true, SLEEPIN = true, TURNON = true, TURNOFF = true,
    ACTIVATE = true, OPEN = true, CLOSE = true,
}

local COMMUNITY_ACTION_ALLOWLIST = {
    WALKTO = true,
    PICKUP = true,
}

function M.IsBlockedAction(action)
    return type(action) == "string" and BLOCKED_ACTIONS[action] == true
end

function M.IsServerActionAllowed(action)
    return type(action) == "string"
        and not M.IsBlockedAction(action)
        and SERVER_ACTION_ALLOWLIST[action] == true
end

function M.IsCommunityActionAllowed(action)
    return type(action) == "string"
        and not M.IsBlockedAction(action)
        and COMMUNITY_ACTION_ALLOWLIST[action] == true
end

function M.IsClientActionAllowed(action, extra_allowed)
    if type(action) ~= "string" or M.IsBlockedAction(action) then
        return false
    end
    return SERVER_ACTION_ALLOWLIST[action] == true
        or (type(extra_allowed) == "table" and extra_allowed[action] == true)
end

function M.IsOwnerModConfirmedLoaded(snapshot, owner_mod_id)
    if type(owner_mod_id) ~= "string" or #owner_mod_id < 1 or #owner_mod_id > 64 then
        return false, "invalid_owner_mod_id"
    end
    if type(snapshot) ~= "table" or type(snapshot.capabilities) ~= "table"
        or snapshot.capabilities.loaded_mod_list ~= true then
        return false, "loaded_mod_list_unavailable"
    end
    if type(snapshot.mods) ~= "table" then
        return false, "mod_list_unavailable"
    end
    for _, mod in ipairs(snapshot.mods) do
        if type(mod) == "table" and mod.id == owner_mod_id then
            if mod.enabled_known ~= true or mod.enabled ~= true then
                return false, "owner_mod_not_enabled"
            end
            if mod.loaded_known ~= true or mod.loaded ~= true or mod.load_state ~= "loaded" then
                return false, "owner_mod_not_confirmed_loaded"
            end
            if mod.metadata_available ~= true or mod.server_enabled_known ~= true
                or mod.server_enabled ~= true then
                return false, "owner_mod_not_confirmed_server_enabled"
            end
            return true, "confirmed"
        end
    end
    return false, "owner_mod_not_found"
end

local function deep_equal(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] ~= nil then return seen[left] == right end
    seen[left] = right
    for key, value in pairs(left) do
        if not deep_equal(value, right[key], seen) then return false end
    end
    for key, value in pairs(right) do
        if not deep_equal(left[key], value, seen) then return false end
    end
    return true
end

function M.ValidateCommunityPlan(plan, registered_suites, embedded_ai)
    if type(plan) ~= "table" or type(plan.suite_id) ~= "string"
        or type(plan.owner_mod_id) ~= "string" or type(plan.scenario_id) ~= "string"
        or type(plan.run_id) ~= "string" then
        return false, "community_suite_identity_missing"
    end
    if type(registered_suites) ~= "table" then
        return false, "community_suite_registry_unavailable"
    end
    local registered_suite
    for _, candidate in ipairs(registered_suites) do
        if type(candidate) == "table" and candidate.id == plan.suite_id
            and candidate.owner_mod_id == plan.owner_mod_id then
            registered_suite = candidate
            break
        end
    end
    if registered_suite == nil then
        return false, "community_suite_not_registered_on_master"
    end
    if type(embedded_ai) ~= "table" or type(embedded_ai.BuildVirtualPlayerPlan) ~= "function" then
        return false, "community_suite_compiler_unavailable"
    end
    local expected, reason = embedded_ai.BuildVirtualPlayerPlan(
        registered_suite, plan.scenario_id, plan.run_id)
    if type(expected) ~= "table" then
        return false, "registered_suite_scenario_unavailable: " .. tostring(reason)
    end
    if not deep_equal(plan, expected) then
        return false, "community_plan_differs_from_registered_declaration"
    end
    return true, "registered_suite_plan"
end

return M
