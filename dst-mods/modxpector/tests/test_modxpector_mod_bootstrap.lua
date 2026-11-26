-- luacheck: globals MOD_RPC AddModRPCHandler AddClientModRPCHandler AddPlayerPostInit
-- luacheck: globals GetModConfigData TheNet Prefabs AllRecipes SendModRPCToClient SpawnPrefab
local rpc_server, rpc_client, player_postinit = {}, {}, nil
MOD_RPC = {}
local admin = false
local now = 1
local configured_max_spawn_count = 20
local laboratory_mode = false
local responses = {}
local spawned_items = 0
local inventory_accepts_items = true
local query_calls = 0
local sent_plan_rpc
local virtual_player_started
local pending_master_timeout
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
    if name == "collect_runtime_components" then error("synthetic optional config failure") end
    if name == "test_mode" then return true end
    if name == "laboratory_mode" then return laboratory_mode end
    if name == "max_spawn_count" then return configured_max_spawn_count end
    return nil
end
TheNet = {
    IsDedicated = function() return false end,
    GetClientTableForUser = function() return { admin = admin } end,
}
TheWorld = { ismastersim = true }
local TheSim = { QueryServer = function() query_calls = query_calls + 1 end }
Prefabs = { cutgrass = true, grass = true }
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

local ChatTypes = { Message = "message", SystemMessage = "system", CommandResponse = "command_response" }
local function make_chat_history()
    local history = { listeners = {}, system_messages = {}, command_responses = {}, add_count = 0, remove_count = 0 }
    function history:AddChatHistoryListener(fn)
        self.listeners[fn] = true
        self.add_count = self.add_count + 1
    end
    function history:RemoveChatHistoryListener(fn)
        self.listeners[fn] = nil
        self.remove_count = self.remove_count + 1
    end
    function history:OnSystemMessage(message)
        self.system_messages[#self.system_messages + 1] = message
        for listener in pairs(self.listeners) do
            listener({ type = ChatTypes.SystemMessage, message = message })
        end
    end
    function history:SendCommandResponse(message)
        self.command_responses[#self.command_responses + 1] = message
        for listener in pairs(self.listeners) do
            listener({ type = ChatTypes.CommandResponse, message = message })
        end
    end
    return history
end
local chat_history = make_chat_history()

local player = {
    userid = "KU_TEST_USER",
    IsValid = function() return true end,
    DoTaskInTime = function(_, delay, callback)
        if delay >= 20 then pending_master_timeout = callback else callback() end
    end,
    components = {
        builder = { UnlockRecipe = function(_, recipe) unlocked[recipe] = true end },
        inventory = { GiveItem = function()
            spawned_items = spawned_items + 1
            return inventory_accepts_items
        end },
    },
}

local engine_globals = { pcall = pcall, rawset = rawset }
engine_globals.Prefabs = Prefabs
-- ThePlayer is exposed by the mod environment, not required to be a raw GLOBAL field.
engine_globals.ChatHistory = chat_history
engine_globals.ChatTypes = ChatTypes
local env = setmetatable({
    GLOBAL = engine_globals,
    require = function(path)
        if path == "modxpector/test_plan" then
            return { schema = "modxpector/test-plan/v1", enabled = true, run_id = "run_1",
                allow_non_admin_test_player = false, allowed_prefabs = { "cutgrass" },
                allowed_recipes = { "axe" }, steps = {} }
        elseif path == "modxpector/runtime_observer" then
            return dofile("dst-mods/modxpector/scripts/modxpector/runtime_observer.lua")
        elseif path == "modxpector/community_events" then
            return dofile("dst-mods/modxpector/scripts/modxpector/community_events.lua")
        elseif path == "modxpector/chat_commands" then
            return dofile("dst-mods/modxpector/scripts/modxpector/chat_commands.lua")
        elseif path == "modxpector/embedded_ai" then
            return dofile("dst-mods/modxpector/scripts/modxpector/embedded_ai.lua")
        elseif path == "modxpector/test_plan_policy" then
            return dofile("dst-mods/modxpector/scripts/modxpector/test_plan_policy.lua")
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
                    mods = {
                        { id = "workshop-100", name = "Community Test Mod",
                            enabled = true, enabled_known = true,
                            loaded = true, loaded_known = true, load_state = "loaded",
                            metadata_available = true, server_enabled = true, server_enabled_known = true },
                    },
                }
            end }
        elseif path == "modxpector/virtual_player_client" then
            return { new = function(_, options)
                return {
                    Start = function(self, plan)
                        virtual_player_started = plan
                        return true
                    end,
                    OnRPCResult = function() end,
                    running = false,
                }
            end }
        end
        return require(path)
    end,
    type = type, tostring = tostring, tonumber = tonumber, math = math,
    GetModConfigData = GetModConfigData, AddModRPCHandler = AddModRPCHandler,
    AddClientModRPCHandler = AddClientModRPCHandler, AddPlayerPostInit = AddPlayerPostInit,
    TheNet = TheNet, TheWorld = TheWorld, TheSim = TheSim, ThePlayer = player,
    ChatHistory = chat_history, ChatTypes = ChatTypes,
    Prefabs = Prefabs, AllRecipes = AllRecipes,
    GetTime = GetTime, SendModRPCToClient = SendModRPCToClient, SpawnPrefab = SpawnPrefab,
    MOD_RPC = MOD_RPC, modname = "modxpector_agent_test", print = function() end,
    json = { decode = function() return decoded_plan end, encode = function() return "{}" end },
    SendModRPCToServer = function(rpc, run_id, encoded) sent_plan_rpc = { rpc = rpc, run_id = run_id, encoded = encoded } end,
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
assert(source:find('inventario_indisponivel', 1, true),
    "embedded AI must report when the read-only inventory is unavailable")
assert(source:find('DST_GLOBAL.MODXPECTOR_LAST_VIRTUAL_PLAYER_REPORT', 1, true),
    "Virtual Player reports must remain available in the game session")
assert(source:find('DST_GLOBAL.MODXPECTOR_REPORT_DIAGNOSTIC_EVENT = report_community_diagnostic_event', 1, true),
    "community mods must receive the opt-in diagnostic event API")
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
local suite_registered, suite_message = engine_globals.MODXPECTOR_REGISTER_TEST_SUITE({
    schema = "modxpector/test-suite/v1",
    id = "community_grass_smoke",
    owner_mod_id = "workshop-100",
    title = "Community grass smoke test",
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "WALKTO" },
    scenarios = {
        { id = "approach_grass", title = "Approach grass", steps = {
            { kind = "action", action = "WALKTO", target = { prefab = "grass", radius = 12 }, target_required = true },
            { kind = "assert", assertion = { kind = "player_near_target", target_step = 1, radius = 4 }, verifies_step = 1 },
        } },
    },
})
assert(suite_registered == true and suite_message == "registered", "valid community suite must register")

local pickup_suite_registered, pickup_suite_message = engine_globals.MODXPECTOR_REGISTER_TEST_SUITE({
    schema = "modxpector/test-suite/v1",
    id = "pickup_smoke",
    owner_mod_id = "workshop-100",
    title = "Community pickup smoke test",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = { "PICKUP" },
    scenarios = {
        { id = "pickup_item", title = "Pick up cut grass", steps = {
            { kind = "action", action = "PICKUP",
                target = { prefab = "cutgrass", radius = 12 }, target_required = true },
            { kind = "assert", assertion = {
                kind = "player_inventory_item_count_increased",
                target_step = 1, prefab = "cutgrass", count = 1,
            }, verifies_step = 1 },
        } },
    },
})
assert(pickup_suite_registered == true and pickup_suite_message == "registered",
    "valid bounded PICKUP suite must register on the Master")

-- Joining a world starts the embedded read-only analysis and never contacts localhost.
player_postinit(player)
assert(chat_history.add_count == 1, "the local ChatHistory listener must be registered once")
local first_chat_listener
for listener in pairs(chat_history.listeners) do first_chat_listener = listener end
assert(type(first_chat_listener) == "function")
first_chat_listener({
    type = ChatTypes.Message,
    sender_userid = player.userid,
    message = "/mx status",
})
assert(#chat_history.command_responses == 1
    and string.find(chat_history.command_responses[1], "ModXpector: IA", 1, true),
    "the chat listener must answer supported commands through SendCommandResponse")

-- The listener must resolve the current player after reconnect rather than retaining a stale entity.
player.userid = nil
local reconnected_player = {
    userid = "KU_TEST_USER",
    Transform = { GetWorldPosition = function() return 0, 0, 0 end },
    IsValid = function() return true end,
    DoTaskInTime = function(_, delay, callback) if delay >= 20 then pending_master_timeout = callback else callback() end end,
    components = player.components,
}
env.ThePlayer = reconnected_player
-- The mod environment's ThePlayer binding is replaced on reconnect.
player_postinit(reconnected_player)
assert(chat_history.add_count == 1 and chat_history.remove_count == 0,
    "reconnect with the same history manager must not duplicate the listener")
first_chat_listener({
    type = ChatTypes.Message,
    sender_userid = reconnected_player.userid,
    message = "/mx status",
})
assert(#chat_history.command_responses == 2,
    "the existing listener must use the replacement local player entity")

-- If DST replaces the ChatHistory manager, remove the old callback and bind to the new manager.
local replacement_history = make_chat_history()
engine_globals.ChatHistory = replacement_history
player_postinit(reconnected_player)
assert(chat_history.remove_count == 1 and next(chat_history.listeners) == nil)
assert(replacement_history.add_count == 1)
local replacement_listener
for listener in pairs(replacement_history.listeners) do replacement_listener = listener end
replacement_listener({
    type = ChatTypes.Message,
    sender_userid = reconnected_player.userid,
    message = "/mx status",
})
assert(#replacement_history.command_responses == 1,
    "the replacement history manager must receive chat command responses")

assert(query_calls == 0, "embedded AI must not make localhost HTTP calls")
assert(type(engine_globals.MODXPECTOR_RUN_EMBEDDED_AI) == "function")
assert(type(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT) == "table",
    "the embedded AI should produce a diagnostic report during player initialization")
assert(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.analysis.status == "incomplete_evidence",
    "the synthetic inventory should report the disabled optional component observer as a limitation")
assert(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.runtime_components.enabled == false
    and engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.runtime_components.available == false,
    "runtime component observation must remain disabled by default in the game bootstrap")
assert(type(engine_globals.MODXPECTOR_REPORT_DIAGNOSTIC_EVENT) == "function",
    "community mods must receive a bounded diagnostic event API")
local community_event_ok, community_event_reason = engine_globals.MODXPECTOR_REPORT_DIAGNOSTIC_EVENT({})
assert(community_event_ok == false and community_event_reason == "disabled_by_configuration",
    "community event ingestion must remain opt-in by default")
assert(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.community_events.enabled == false,
    "the embedded AI report must expose community event ingestion as disabled by default")
local selected_suite_ids = {}
for _, entry in ipairs(engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.selected_suites) do
    if type(entry) == "table" and type(entry.suite) == "table" then
        selected_suite_ids[entry.suite.id] = true
    end
end
assert(#engine_globals.MODXPECTOR_EMBEDDED_AI_REPORT.selected_suites == 2,
    "both active community suites with available prefabs should be selected")
assert(selected_suite_ids.community_grass_smoke == true and selected_suite_ids.pickup_smoke == true,
    "the embedded AI should select both the WALKTO and PICKUP suites")

-- The generated WALKTO suite moves the real local character, so the successful
-- Master-acceptance path must explicitly opt into a disposable lab world.
laboratory_mode = true
local suite_request_ok, suite_request_message = engine_globals.MODXPECTOR_RUN_AI_SUITE(
    "community_grass_smoke", "approach_grass")
assert(suite_request_ok == true and sent_plan_rpc ~= nil,
    "embedded AI should compile and send the selected suite to the Master")
assert(sent_plan_rpc.encoded == "{}" and string.match(sent_plan_rpc.run_id, "^[%w_%-]+$") ~= nil,
    "suite plan RPC must use a serialized payload and safe run identifier")
rpc_client.plan_ready(sent_plan_rpc.run_id, true, "accepted")
assert(virtual_player_started ~= nil and virtual_player_started.schema == "modxpector/test-plan/v1",
    "Master acceptance must start the Virtual Player with the generated plan")
assert(virtual_player_started.suite_id == "community_grass_smoke"
    and virtual_player_started.scenario_id == "approach_grass",
    "Virtual Player plan must retain suite provenance")
assert(type(pending_master_timeout) == "function", "Master validation must have a bounded timeout")
pending_master_timeout() -- accepted plans must ignore the stale timeout callback

now = 2
local rejected_request_ok = engine_globals.MODXPECTOR_RUN_AI_SUITE("community_grass_smoke", "approach_grass")
assert(rejected_request_ok == true and sent_plan_rpc ~= nil)
rpc_client.plan_ready(sent_plan_rpc.run_id, false, "permission denied")
assert(engine_globals.MODXPECTOR_EMBEDDED_AI_LAST_SUITE_RESULT.status == "inconclusive",
    "Master rejection must be recorded as inconclusive, not as a passed test")

assert(type(rpc_server.spawn_item) == "function")
assert(type(rpc_server.spawn_entity) == "function")
assert(type(rpc_server.unlock_recipe) == "function")
assert(type(rpc_client.action_result) == "function")
assert(type(player_postinit) == "function")

-- Effectful RPCs require an active Master-approved plan with exact operation steps.
admin = true
laboratory_mode = true
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "server_rpc_ops",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = { "axe" },
    allowed_actions = {},
    steps = {
        { kind = "unlock_recipe", recipe = "axe" },
        { kind = "spawn_item", prefab = "cutgrass", count = 2 },
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
        { kind = "spawn_item", prefab = "cutgrass", count = 6 },
        { kind = "spawn_item", prefab = "cutgrass", count = 5 },
        { kind = "spawn_item", prefab = "cutgrass", count = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "server_rpc_ops", "{}")
assert(responses[#responses].success == true, "Master must accept the disposable-lab operation plan")

admin = false
rpc_server.unlock_recipe(reconnected_player, 1, 1, "server_rpc_ops", "axe")
assert(unlocked.axe == nil and responses[#responses].success == false)
admin = true
laboratory_mode = false
now = 1.2
rpc_server.unlock_recipe(reconnected_player, 2, 1, "server_rpc_ops", "axe")
assert(unlocked.axe == nil and responses[#responses].success == false
    and string.find(responses[#responses].message, "laboratory mode", 1, true),
    "recipe unlock must be blocked when disposable laboratory mode is disabled")
laboratory_mode = true
now = 1.4
rpc_server.unlock_recipe(reconnected_player, 3, 1, "server_rpc_ops", "axe")
assert(unlocked.axe == true and responses[#responses].success == true)
now = 1.6
rpc_server.spawn_item(reconnected_player, 4, 2, "server_rpc_ops", "cutgrass", 2, 0, 0)
assert(spawned_items == 2 and responses[#responses].success == true)
rpc_server.spawn_item(reconnected_player, 5, 3, "server_rpc_ops", "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false and string.find(responses[#responses].message, "rate limit", 1, true))

-- The configured per-request limit must be enforced by the master, not only displayed in the UI.
configured_max_spawn_count = 5
now = 1.8
rpc_server.spawn_item(reconnected_player, 6, 4, "server_rpc_ops", "cutgrass", 6, 0, 0)
assert(spawned_items == 2 and responses[#responses].success == false)
assert(string.find(responses[#responses].message, "configured limit", 1, true))
now = 2.0
rpc_server.spawn_item(reconnected_player, 7, 5, "server_rpc_ops", "cutgrass", 5, 0, 0)
assert(spawned_items == 7 and responses[#responses].success == true)

-- A created prefab is not a successful spawn_item unless GiveItem confirms inventory delivery.
inventory_accepts_items = false
now = 2.2
rpc_server.spawn_item(reconnected_player, 8, 3, "server_rpc_ops", "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "inventory rejected", 1, true))
inventory_accepts_items = true

-- Wrong positions, run IDs, step kinds, replays and calls after plan clear fail closed.
now = 2.4
rpc_server.spawn_item(reconnected_player, 9, 6, "server_rpc_ops", "cutgrass", 1, 100, 100)
assert(responses[#responses].success == false and spawned_items == 8
    and string.find(responses[#responses].message, "outside the authorized plan position", 1, true))
now = 2.6
rpc_server.spawn_item(reconnected_player, 10, 6, "stale_run_id", "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false and spawned_items == 8)
now = 2.8
rpc_server.unlock_recipe(reconnected_player, 11, 6, "server_rpc_ops", "axe")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "does not match", 1, true))
now = 3.0
rpc_server.unlock_recipe(reconnected_player, 12, 1, "server_rpc_ops", "axe")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "already consumed", 1, true))
rpc_server.clear_test_plan(reconnected_player, "server_rpc_ops")
now = 3.2
rpc_server.spawn_item(reconnected_player, 13, 6, "server_rpc_ops", "cutgrass", 1, 0, 0)
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "no active Master-approved", 1, true))
print("MODXPECTOR_SPAWN_ITEM_INVENTORY_DELIVERY_CONTRACT_OK")
print("MODXPECTOR_CONFIGURED_SPAWN_LIMIT_CONTRACT_OK")
print("MODXPECTOR_MOD_BOOTSTRAP_SECURITY_CONTRACT_OK")

-- Movement is an action on the real local character and must also stay inside the disposable lab.
laboratory_mode = false
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "walkto_requires_laboratory",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "action", action = "WALKTO", target = { prefab = "cutgrass" }, target_required = true },
    },
}
rpc_server.set_test_plan(reconnected_player, "walkto_requires_laboratory", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "laboratory mode", 1, true),
    "Master must reject movement plans outside the disposable laboratory")

-- World-changing plans must be rejected unless the server explicitly confirms a disposable lab world.
laboratory_mode = false
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "blocked_without_laboratory",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = { { kind = "spawn_item", prefab = "cutgrass", count = 1 } },
}
rpc_server.set_test_plan(reconnected_player, "blocked_without_laboratory", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "laboratory mode", 1, true),
    "Master must reject world-changing plans when laboratory mode is disabled")
laboratory_mode = true

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
rpc_server.set_test_plan(reconnected_player, "valid_plan_1", "{}")
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
rpc_server.set_test_plan(reconnected_player, "valid_target_1", "{}")
assert(responses[#responses].success == true, "master must accept an exact prior-action target reference")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "valid_store_container_assertion",
    allowed_prefabs = { "cutgrass", "treasurechest" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "action", action = "STORE", target = { prefab = "treasurechest" }, target_required = true, invobject = "cutgrass" },
        { kind = "assert", assertion = { kind = "container_item_count_increased", target_step = 1, prefab = "cutgrass", count = 1 }, verifies_step = 1 },
        { kind = "assert", assertion = { kind = "player_inventory_item_count_decreased", target_step = 1, prefab = "cutgrass", count = 1 }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "valid_store_container_assertion", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "inventory transfer actions are disabled", 1, true),
    "Master must keep STORE blocked until exact item identity and container transition are verified")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "valid_takeitem_action",
    allowed_prefabs = { "birdcage", "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "action", action = "TAKEITEM", target = { prefab = "birdcage" }, target_required = true },
        { kind = "assert", assertion = { kind = "player_inventory_item_count_increased", target_step = 1, prefab = "cutgrass", count = 1 }, verifies_step = 1 },
        { kind = "assert", assertion = { kind = "target_has_tag", target_step = 1, tag = "inventoryitemholder_take", expected = false }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "valid_takeitem_action", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "inventory transfer actions are disabled", 1, true),
    "Master must keep TAKEITEM blocked until exact item identity and container transition are verified")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "invalid_legacy_take_action",
    allowed_prefabs = { "birdcage" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "action", action = "TAKE", target = { prefab = "birdcage" }, target_required = true },
    },
}
rpc_server.set_test_plan(reconnected_player, "invalid_legacy_take_action", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "server allowlist", 1, true),
    "master must reject the nonexistent TAKE action")

decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "invalid_container_count",
    allowed_prefabs = { "treasurechest", "cutgrass" },
    allowed_recipes = {},
    allowed_actions = {},
    steps = {
        { kind = "assert", assertion = { kind = "container_has_item", target = { prefab = "treasurechest" }, prefab = "cutgrass", count = 1.5 } },
    },
}
rpc_server.set_test_plan(reconnected_player, "invalid_container_count", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "container assertion count", 1, true),
    "master must reject fractional container assertion counts")

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
rpc_server.set_test_plan(reconnected_player, "invalid_future_ref", "{}")
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
rpc_server.set_test_plan(reconnected_player, "invalid_target_ref", "{}")
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
rpc_server.set_test_plan(reconnected_player, "invalid_inventory_count", "{}")
assert(responses[#responses].success == false)
assert(string.find(responses[#responses].message, "inventory assertion count", 1, true))
print("MODXPECTOR_MASTER_TEST_PLAN_VALIDATION_CONTRACT_OK")


-- Inventory transfer actions remain fail-closed regardless of declared targets or postconditions.
for _, blocked_action in ipairs({ "STORE", "TAKEITEM", "TAKESINGLEITEM" }) do
    decoded_plan = {
        schema = "modxpector/test-plan/v1",
        enabled = true,
        run_id = "blocked_" .. string.lower(blocked_action),
        allowed_prefabs = { "cutgrass", "treasurechest", "birdcage" },
        allowed_recipes = {},
        allowed_actions = { blocked_action },
        steps = {
            {
                kind = "action", action = blocked_action,
                target = { prefab = blocked_action == "STORE" and "treasurechest" or "birdcage" },
                target_required = true, invobject = "cutgrass",
            },
            {
                kind = "assert",
                assertion = { kind = "player_inventory_item_count_increased", target_step = 1, prefab = "cutgrass", count = 1 },
                verifies_step = 1,
            },
        },
    }
    rpc_server.set_test_plan(reconnected_player, "blocked_" .. string.lower(blocked_action), "{}")
    assert(responses[#responses].success == false
        and string.find(responses[#responses].message, "inventory transfer actions are disabled", 1, true),
        blocked_action .. " must remain blocked even when a plan declares target and postcondition evidence")
end

-- Community-suite plans are independently constrained by the Master AI allowlist.
admin = true
laboratory_mode = true
now = now + 1
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "suite_pickup_valid",
    suite_id = "pickup_smoke",
    owner_mod_id = "workshop-100",
    scenario_id = "pickup_item",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = { "PICKUP" },
    steps = {
        { kind = "action", action = "PICKUP",
            target = { prefab = "cutgrass", radius = 12 }, target_required = true },
        { kind = "assert", assertion = {
            kind = "player_inventory_item_count_increased",
            target_step = 1, prefab = "cutgrass", count = 1,
        }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "suite_pickup_valid", "{}")
assert(responses[#responses].success == true,
    "Master should accept a bounded PICKUP suite with an inventory-delta postcondition")

now = now + 1
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "suite_attack_rejected",
    suite_id = "unapproved_attack_suite",
    owner_mod_id = "workshop-100",
    scenario_id = "attack_item",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = { "ATTACK" },
    steps = {
        { kind = "action", action = "ATTACK",
            target = { prefab = "cutgrass", radius = 12 }, target_required = true },
        { kind = "assert", assertion = {
            kind = "target_exists", target_step = 1, expected = true,
        }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "suite_attack_rejected", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message,
        "action is not in the server-side AI suite allowlist", 1, true),
    "Master must reject client-supplied community-suite actions outside its independent allowlist")



now = now + 1
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "suite_pickup_missing_postcondition",
    suite_id = "pickup_smoke",
    owner_mod_id = "workshop-100",
    scenario_id = "pickup_item",
    allowed_prefabs = { "cutgrass" },
    allowed_recipes = {},
    allowed_actions = { "PICKUP" },
    steps = {
        { kind = "action", action = "PICKUP",
            target = { prefab = "cutgrass", radius = 12 }, target_required = true },
    },
}
rpc_server.set_test_plan(reconnected_player, "suite_pickup_missing_postcondition", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "community_plan_differs_from_registered_declaration", 1, true),
    "Master must reject a client plan that removes the registered PICKUP postcondition")

now = now + 1
decoded_plan = {
    schema = "modxpector/test-plan/v1",
    enabled = true,
    run_id = "suite_pickup_mismatched_prefab",
    suite_id = "pickup_smoke",
    owner_mod_id = "workshop-100",
    scenario_id = "pickup_item",
    allowed_prefabs = { "cutgrass", "grass" },
    allowed_recipes = {},
    allowed_actions = { "PICKUP" },
    steps = {
        { kind = "action", action = "PICKUP",
            target = { prefab = "cutgrass", radius = 12 }, target_required = true },
        { kind = "assert", assertion = {
            kind = "player_inventory_item_count_increased",
            target_step = 1, prefab = "grass", count = 1,
        }, verifies_step = 1 },
    },
}
rpc_server.set_test_plan(reconnected_player, "suite_pickup_mismatched_prefab", "{}")
assert(responses[#responses].success == false
    and string.find(responses[#responses].message, "community_plan_differs_from_registered_declaration", 1, true),
    "Master must reject a client plan that changes the registered pickup prefab proof")

