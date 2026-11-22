-- luacheck: globals MOD_RPC AddModRPCHandler AddClientModRPCHandler AddPlayerPostInit
-- luacheck: globals GetModConfigData TheNet Prefabs AllRecipes SendModRPCToClient SpawnPrefab
local rpc_server, rpc_client, player_postinit = {}, {}, nil
MOD_RPC = {}
local admin = false
local now = 1
local responses = {}
local spawned_items = 0
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
    if name == "max_spawn_count" then return 20 end
    return nil
end
TheNet = {
    IsDedicated = function() return true end,
    GetClientTableForUser = function() return { admin = admin } end,
}
TheWorld = { ismastersim = true }
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
    TheNet = TheNet, TheWorld = TheWorld, Prefabs = Prefabs, AllRecipes = AllRecipes,
    GetTime = GetTime, SendModRPCToClient = SendModRPCToClient, SpawnPrefab = SpawnPrefab,
    MOD_RPC = MOD_RPC, modname = "modxpector_agent_test", print = function() end,
}, { __index = function(_, name)
    if name == "pcall" then return nil end
    return _G[name]
end })

local file = assert(io.open("dst-mods/modxpector/modmain.lua", "r"))
local source = file:read("*a")
file:close()
local chunk = assert(loadstring(source, "@modxpector/modmain.lua"))
setfenv(chunk, env)
chunk()

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
print("MODXPECTOR_MOD_BOOTSTRAP_SECURITY_CONTRACT_OK")
