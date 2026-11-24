-- luacheck: globals MOD_RPC AddModRPCHandler AddClientModRPCHandler AddPlayerPostInit
-- luacheck: globals GetModConfigData TheNet Prefabs AllRecipes SendModRPCToClient SpawnPrefab
local rpc_server, rpc_client, player_postinit = {}, {}, nil
MOD_RPC = {}
local admin = false
local now = 1
local configured_max_spawn_count = 20
local responses = {}
local spawned_items = 0
local inventory_accepts_items = true
local query_calls = 0
local unlocked = {}
local decoded_plan

AddModRPCHandler = function(mod, name, fn)
    rpc_server[name] = fn
    MOD_RPC[mod] = MOD_RPC[mod] or {}
    MOD_RPC[mod][name] = { name = name }
end
AddClientModRPCHandler = function(mod, name, fn)
    rpc_client[name] = fn
    MOD_RPC[mod] = MOD_RPC[mod] or {}
    MOD_RPC[mod][name] = { name = name }
end
AddPlayerPostInit = function(fn) player_postinit = fn end
GetModConfigData = function(name)
    if name == "test_mode" then return true end
    if name == "max_spawn_count" then return configured_max_spawn_count end
    return nil
end
TheNet = {
    IsDedicated = function() return false end,
    GetClientTableForUser = function() return { admin = admin } end,
}
TheWorld = { ismastersim = true }
local TheSim = { QueryServer = function() query_calls = query_calls + 1 end }
Prefabs = { cutgrass = true }
AllRecipes = { axe = { name = "axe" } }
GetTime = function() return now end
SendModRPCToClient = function(rpc, userid, request_id, success, message)
    responses[#responses + 1] = {
        rpc = rpc, userid = userid, request_id = request_id,
        success = success, message = message,
    }
end
SpawnPrefab = function(prefab)
    assert(prefab == "cutgrass")
    return { IsValid = function() return true end, Transform = { SetPosition = function() end } }
end

local player = {
    userid = "KU_TEST_USER",
    IsValid = function() return true end,
    DoTaskInTime = function(_, _, callback) callback() end,
    components = {
        builder = { UnlockRecipe = function(_, recipe) unlocked[recipe] = true end },
        inventory = { GiveItem = function()
            spawned_items = spawned_items + 1
            return inventory_accepts_items
        end },
    },
}

local engine_globals = { pcall = pcall, rawset = rawset }
local env = setmetatable({
    GLOBAL = engine_globals,
    require = function(path)
        if path == "modxpector/test_plan" then
            return { schema = "modxpector/test-plan/v1", enabled = true, run_id = "run_1",
                allow_non_admin_test_player = false, allowed_prefabs = { "cutgrass" },
                allowed_recipes = { "axe" }, steps = {} }
        elseif path == "modxpector/embedded_ai" then
            return dofile("dst-mods/modxpector/scripts/modxpector/embedded_ai.lua")
        elseif path == "modxpector/world_inventory" then
            return { Collect = function()
                return {
                    schema = "modxpector/world-inventory/v2",
                    captured_at = 1,
                    truncated = false,
                    capabilities = {
                        known_mod_list = true,
                        loaded_mod_list = true,
                        failed_mod_list = true,
                    },
                    mods = {},
                }
            end }
        end
        return require(path)
    end,
    type = type, tostring = tostring, tonumber = tonumber, math = math,
    GetModConfigData = GetModConfigData, AddModRPCHandler = AddModRPCHandler,
    AddClientModRPCHandler = AddClientModRPCHandler, AddPlayerPostInit = AddPlayerPostInit,
    TheNet = TheNet, TheWorld = TheWorld, TheSim = TheSim, ThePlayer = player,
    Prefabs = Prefabs, AllRecipes = AllRecipes,
    GetTime = GetTime, SendModRPCToClient = SendModRPCToClient, SpawnPrefab = SpawnPrefab,
    MOD_RPC = MOD_RPC, modname = "modxpector_agent_test", print = function() end,
    json = { decode = function() return decoded_plan end },
}, { __index = function(_, name)
    if name == "pcall" then return nil end
    return _G[name]
end })

local file = assert(io.open("dst-mods/modxpector/modmain.lua", "r"))
local source = file:read("*a")
local inventory_guard = source:find('if not INVENTORY_OK or type(WORLD_INVENTORY) ~= "table"', 1, true)
local inventory_collect = source:find('pcall(WORLD_INVENTORY.Collect, DST_GLOBAL)', 1, true)
assert(inventory_guard ~= nil and inventory_collect ~= nil and inventory_guard < inventory_collect,
    "world inventory must fail closed before calling Collect when its module failed to load")
assert(source:find('world_inventory_module_unavailable', 1, true),
    "inventory failure must return an explicit unavailable status")
assert(source:find('DST_GLOBAL.MODXPECTOR_LAST_VIRTUAL_PLAYER_REPORT', 1, true),
    "Virtual Player reports must remain available in the game session")
assert(source:find('DST_GLOBAL.MODXPECTOR_RUN_EMBEDDED_AI = run_embedded_ai_diagnostics', 1, true),
    "the embedded diagnostic engine must be exposed to the dashboard")
local inventory_file = assert(io.open("dst-mods/modxpector/scripts/modxpector/world_inventory.lua", "r"))
local inventory_source = inventory_file:read("*a")
inventory_file:close()
assert(not inventory_source:find("GLOBAL or _G", 1, true),
    "inventory module must not resolve undeclared GLOBAL while it is required")
file:close()
local chunk = assert(loadstring(source, "@modxpector/modmain.lua"))
setfenv(chunk, env)
chunk()

-- Joining a world starts the embedded read-only analysis and never contacts localhost.
player_postinit(player)
assert(query_calls == 0, "embedded AI must not make localhost HTTP calls")
assert(type(engine_globals.MODXPECTOR_RUN_EMBEDDED_AI) == "function")
assert(type(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT) == "table",
    "the embedded AI should produce a diagnostic report during player initialization")
assert(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.analysis.status == "no_known_issues",
    "the empty synthetic inventory should produce a clean, evidence-backed analysis")

assert(type(rpc_server.spawn_item) == "function")
assert(type(rpc_server.spawn_entity) == "function")
assert(type(rpc_server.unlock_recipe) == "function")
assert(type(rpc_client.action_result) == "function")
assert(type(player_postinit) == "function")

rpc_server.unlock_recipe(player, 1, "axe")
assert(unlocked.axe == nil and responses[#responses].success == false)
admin = true
now = 1.2
rpc_server.unlock_recipe(player, 2, "axe")
assert(unlocked.axe == true and responses[#responses].success == true)
now = 1.4
rpc_server.spawn_item(player, 3, "cutgrass", 2, 0, 0)
assert(spawned_items == 2 and responses[#responses].success == true)
rpc_server.spawn_item(player, 4, "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false and string.find(responses[#responses].message, "rate limit", 1, true))

-- The configured per-request limit must be enforced by the master, not only displayed in the UI.
configured_max_spawn_count = 5
now = 1.6
rpc_server.spawn_item(player, 5, "cutgrass", 6, 0, 0)
assert(spawned_items == 2 and responses[#responses].success == false)
assert(string.find(responses[#responses].message, "configured limit", 1, true))
now = 1.8
rpc_server.spawn_item(player, 6, "cutgrass", 5, 0, 0)
assert(spawned_items == 7 and responses[#responses].success == true)

-- A created prefab is not a successful spawn_item unless GiveItem confirms inventory delivery.
inventory_accepts_items = false
now = 2.0
rpc_server.spawn_item(player, 7, "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "inventory rejected", 1, true))
inventory_accepts_items = true
print("MODXPECTOR_SPAWN_ITEM_INVENTORY_DELIVERY_CONTRACT_OK")
print("MODXPECTOR_CONFIGURED_SPAWN_LIMIT_CONTRACT_OK")
print("MODXPECTOR_MOD_BOOTSTRAP_SECURITY_CONTRACT_OK")

-- Master rejects malformed Virtual Player plans before storing them.
admin = true
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "valid_plan_1",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = { "axe" },
    allowed_actions = {},
    steps = {
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 2 }, verifies_steps = { 1, 2 } },
    },
}
rpc_server.set_test_plan(player, "valid_plan_1", "{}")
assert(responses[#responses].success == true, "master must accept valid multiple-postcondition plans")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "valid_target_1",
    allowed_prefabs = { "tree" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "action", action = "CHOP", target = { prefab = "tree" }, target_required = true },
        { kind = "assert", assertion = { kind = "target_dead", target_step = 1 }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(player, "valid_target_1", "{}")
assert(responses[#responses].success == true, "master must accept an exact prior-action target reference")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "invalid_future_ref",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "assert", assertion = { kind = "player_has_item", prefab = "cutgrass" }, verifies_step = 3 },
    },
}
rpc_server.set_test_plan(player, "invalid_future_ref", "{}")
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "invalid postcondition reference", 1, true))

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "invalid_target_ref",
    allowed_prefabs = { "tree" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "wait", seconds = 1 },
        { kind = "assert", assertion = { kind = "target_dead", target_step = 1 } },
    },
}
rpc_server.set_test_plan(player, "invalid_target_ref", "{}")
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "target_step must reference a previous action", 1, true))

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "invalid_inventory_count",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "assert", assertion = { kind = "player_has_item_count_gte", prefab = "cutgrass", count = 1.5 } },
    },
}
rpc_server.set_test_plan(player, "invalid_inventory_count", "{}")
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "inventory assertion count", 1, true))
print("MODXPECTOR_MASTER_TEST_PLAN_VALIDATION_CONTRACT_OK")
