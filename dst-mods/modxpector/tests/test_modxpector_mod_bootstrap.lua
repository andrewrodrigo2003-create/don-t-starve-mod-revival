-- luacheck: globals MOD_RPC AddModRPCHandler AddClientModRPCHandler AddPlayerPostInit
-- luacheck: globals GetModConfigData TheNet Prefabs AllRecipes SendModRPCToClient SpawnPrefab
local rpc_server, rpc_client, player_postinit = {}, {}, nil
MOD_RPC = {}
local admin = false
local now = 1
local configured_max_spawn_count = 20
local responses = {}
local spawned_items = 0
local query_calls = 0
local unlocked = {}

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
        inventory = { GiveItem = function() spawned_items = spawned_items + 1 end },
    },
}

local engine_globals = { pcall = pcall }
local env = setmetatable({
    GLOBAL = engine_globals,
    require = function(path)
        if path == "modxpector/test_plan" then
            return { schema = "modxpector/test-plan/v1", enabled = true, run_id = "run_1",
                allow_non_admin_test_player = false, allowed_prefabs = { "cutgrass" },
                allowed_recipes = { "axe" }, steps = {} }
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
}, { __index = function(_, name)
    if name == "pcall" then return nil end
    return _G[name]
end })

local file = assert(io.open("dst-mods/modxpector/modmain.lua", "r"))
local source = file:read("*a")
local inventory_guard = source:find('if not INVENTORY_OK or type(WORLD_INVENTORY) ~= "table"', 1, true)
local inventory_collect = source:find('pcall(WORLD_INVENTORY.Collect, _G)', 1, true)
assert(inventory_guard ~= nil and inventory_collect ~= nil and inventory_guard < inventory_collect,
    "world inventory must fail closed before calling Collect when its module failed to load")
assert(source:find('world_inventory_module_unavailable', 1, true),
    "inventory failure must return an explicit unavailable status")
file:close()
local chunk = assert(loadstring(source, "@modxpector/modmain.lua"))
setfenv(chunk, env)
chunk()

-- Missing saved config must fail closed: joining a world cannot probe localhost.
player_postinit(player)
assert(query_calls == 0, "local bridge must not probe localhost when ai_bridge_enabled is unset")

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
print("MODXPECTOR_CONFIGURED_SPAWN_LIMIT_CONTRACT_OK")
print("MODXPECTOR_MOD_BOOTSTRAP_SECURITY_CONTRACT_OK")
