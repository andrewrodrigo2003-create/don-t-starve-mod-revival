-- DST runs modmain in a restricted environment where pcall may not be
-- exposed as a direct global. Use the engine global table explicitly.
local DST_GLOBAL = GLOBAL or _G
local pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall
local MODNAME = modname or "modxpector"
local MOD_VERSION = "5.0.14-dev"
local INVENTORY_OK, WORLD_INVENTORY = pcall(require, "modxpector/world_inventory")
if not INVENTORY_OK or type(WORLD_INVENTORY) ~= "table" then
    WORLD_INVENTORY = { Collect = function() return { schema = "modxpector/world-inventory/v1", mods = {}, error = "inventory module unavailable" } end }
end
local PLAN_OK, TEST_PLAN = pcall(require, "modxpector/test_plan")
if not PLAN_OK or type(TEST_PLAN) ~= "table" then
    TEST_PLAN = { schema = "modxpector/test-plan/v1", enabled = false, allowed_prefabs = {}, allowed_recipes = {}, allowed_actions = {}, steps = {} }
end
local CONFIG_SNAPSHOT_OK, CONFIG_SNAPSHOT = pcall(require, "inspector/config_snapshot")
if not CONFIG_SNAPSHOT_OK or type(CONFIG_SNAPSHOT) ~= "table" or type(CONFIG_SNAPSHOT.Read) ~= "function" then
    CONFIG_SNAPSHOT = { Read = function() return {
        open_key = "KEY_F6", show_debug_info = true, ai_bridge_enabled = true,
        test_mode = false, max_spawn_count = 10,
    } end }
end

local active_test_plan = nil
local function current_test_plan()
    return active_test_plan or TEST_PLAN
end

local function is_test_mode_enabled(plan)
    plan = plan or current_test_plan()
    return GetModConfigData("test_mode") == true
        and type(plan) == "table"
        and plan.schema == "modxpector/test-plan/v1"
        and plan.enabled == true
end

local function contains_value(values, value)
    if type(values) ~= "table" then return false end
    if values[value] == true then return true end
    for _, entry in ipairs(values) do
        if entry == value then return true end
    end
    return false
end

local function prefab_is_allowed(prefab, plan)
    return type(prefab) == "string" and contains_value((plan or current_test_plan()).allowed_prefabs, prefab)
end

local function recipe_is_allowed(recipe_name, plan)
    return type(recipe_name) == "string" and #recipe_name > 0 and #recipe_name <= 128
        and contains_value((plan or current_test_plan()).allowed_recipes, recipe_name)
end

local function is_admin_player(player)
    if player == nil or player.userid == nil or TheNet == nil then return false end
    local ok, client = pcall(function() return TheNet:GetClientTableForUser(player.userid) end)
    return ok and client ~= nil and client.admin == true
end

local function send_result(player, request_id, success, message)
    if player == nil or player.userid == nil or type(SendModRPCToClient) ~= "function" then return end
    SendModRPCToClient(MOD_RPC[MODNAME].action_result, player.userid,
        tonumber(request_id) or 0, success == true, tostring(message or ""))
end

local function safe_name_list(values, pattern, maximum)
    if type(values) ~= "table" or #values > maximum then return false end
    for _, value in ipairs(values) do
        if type(value) ~= "string" or #value < 1 or #value > 128 or not value:match(pattern) then
            return false
        end
    end
    return true
end

local function validate_incoming_plan(plan, requested_run_id)
    if type(plan) ~= "table" or plan.schema ~= "modxpector/test-plan/v1" or plan.enabled ~= true then
        return false, "invalid test plan schema or disabled plan"
    end
    if type(plan.run_id) ~= "string" or plan.run_id ~= requested_run_id
        or #plan.run_id < 1 or #plan.run_id > 128 or not plan.run_id:match("^[%w_%-]+$") then
        return false, "invalid test run ID"
    end
    if not safe_name_list(plan.allowed_prefabs or {}, "^[%w_%-]+$", 200)
        or not safe_name_list(plan.allowed_recipes or {}, "^[%w_%-]+$", 200)
        or not safe_name_list(plan.allowed_actions or {}, "^[A-Z0-9_]+$", 200) then
        return false, "invalid test plan allowlist"
    end
    if type(plan.steps) ~= "table" or #plan.steps < 1 or #plan.steps > 200 then
        return false, "test plan must contain 1 to 200 steps"
    end
    return true, "accepted"
end

local spawn_limits = {}
local function allow_spawn_request(player)
    if player == nil or player.userid == nil then return false end
    local now = GetTime()
    local state = spawn_limits[player.userid]
    if state == nil or now - state.window_start >= 5 then
        state = { window_start = now, count = 0, last = -1 }
        spawn_limits[player.userid] = state
    end
    if state.count >= 10 or now - state.last < 0.1 then return false end
    state.count = state.count + 1
    state.last = now
    return true
end

local function handle_set_test_plan(player, run_id, plan_json)
    if TheWorld == nil or not TheWorld.ismastersim then return end
    local function reply(ok, message)
        if player and player.userid and type(SendModRPCToClient) == "function" then
            SendModRPCToClient(MOD_RPC[MODNAME].plan_ready, player.userid, tostring(run_id or ""), ok == true, tostring(message or ""))
        end
    end
    if GetModConfigData("test_mode") ~= true then reply(false, "test mode is disabled"); return end
    if not is_admin_player(player) then reply(false, "administrator permission required"); return end
    if type(plan_json) ~= "string" or #plan_json < 2 or #plan_json > 48 * 1024 then
        reply(false, "test plan payload is outside the allowed size"); return
    end
    local decoded_ok, plan = pcall(function() return json.decode(plan_json) end)
    if not decoded_ok then reply(false, "test plan JSON could not be decoded"); return end
    local valid, reason = validate_incoming_plan(plan, run_id)
    if not valid then reply(false, reason); return end
    active_test_plan = plan
    reply(true, "test plan accepted by master simulation")
end

local function handle_unlock_recipe(player, request_id, recipe_name)
    if TheWorld == nil or not TheWorld.ismastersim then return end
    local plan = current_test_plan()
    if not is_test_mode_enabled(plan) then send_result(player, request_id, false, "test mode disabled"); return end
    if not is_admin_player(player) then send_result(player, request_id, false, "administrator permission required"); return end
    if not allow_spawn_request(player) then send_result(player, request_id, false, "test action rate limit exceeded"); return end
    if not recipe_is_allowed(recipe_name, plan) or AllRecipes == nil or AllRecipes[recipe_name] == nil then
        send_result(player, request_id, false, "recipe is not in the test plan allowlist or is not registered")
        return
    end
    if player.components == nil or player.components.builder == nil then
        send_result(player, request_id, false, "player builder component unavailable")
        return
    end
    local ok, err = pcall(function() player.components.builder:UnlockRecipe(recipe_name) end)
    send_result(player, request_id, ok, ok and ("unlocked recipe " .. recipe_name) or tostring(err))
end

local function handle_spawn(player, request_id, prefab, count, x, z, as_item)
    if TheWorld == nil or not TheWorld.ismastersim then return end
    local plan = current_test_plan()
    if not is_test_mode_enabled(plan) then send_result(player, request_id, false, "test mode disabled"); return end
    if not is_admin_player(player) then send_result(player, request_id, false, "administrator permission required"); return end
    if not allow_spawn_request(player) then send_result(player, request_id, false, "test spawn rate limit exceeded"); return end
    count = tonumber(count)
    if not prefab_is_allowed(prefab, plan) or type(count) ~= "number" or count ~= math.floor(count) or count < 1 or count > 20 then
        send_result(player, request_id, false, "prefab or spawn count is outside the test plan allowlist")
        return
    end
    x, z = tonumber(x), tonumber(z)
    if x == nil or z == nil or x ~= x or z ~= z or math.abs(x) > 100000 or math.abs(z) > 100000 then
        send_result(player, request_id, false, "invalid spawn coordinates")
        return
    end
    local spawned = 0
    for _ = 1, count do
        local ok, entity = pcall(SpawnPrefab, prefab)
        if ok and entity ~= nil and entity:IsValid() then
            if as_item and player.components ~= nil and player.components.inventory ~= nil then
                player.components.inventory:GiveItem(entity)
            else
                entity.Transform:SetPosition(x, 0, z)
            end
            spawned = spawned + 1
        end
    end
    send_result(player, request_id, spawned > 0,
        spawned > 0 and ("spawned " .. tostring(spawned) .. " " .. prefab) or "no prefab instances were created")
end

if type(AddModRPCHandler) == "function" then
    AddModRPCHandler(MODNAME, "set_test_plan", handle_set_test_plan)
    AddModRPCHandler(MODNAME, "clear_test_plan", function(player, run_id)
        if TheWorld == nil or not TheWorld.ismastersim or not is_admin_player(player) then return end
        if active_test_plan ~= nil and active_test_plan.run_id == run_id then active_test_plan = nil end
    end)
    AddModRPCHandler(MODNAME, "spawn_item", function(player, request_id, prefab, count, x, z)
        handle_spawn(player, request_id, prefab, count, x, z, true)
    end)
    AddModRPCHandler(MODNAME, "spawn_entity", function(player, request_id, prefab, count, x, z)
        handle_spawn(player, request_id, prefab, count, x, z, false)
    end)
    AddModRPCHandler(MODNAME, "unlock_recipe", handle_unlock_recipe)
end

local virtual_player
local start_virtual_player
local pending_plan
local bridge_token
local bridge_port = 8765
local bridge_polling = false
local bridge_poll_enabled = false
local poll_game_test_plan

local function schedule_game_poll(inst, delay)
    if inst ~= nil and inst:IsValid() and bridge_poll_enabled and inst == ThePlayer and poll_game_test_plan ~= nil then
        inst:DoTaskInTime(delay or 5, function() poll_game_test_plan(inst) end)
    end
end

local function send_game_report(inst, plan, report, token, port)
    if TheSim == nil or type(TheSim.QueryServer) ~= "function" or type(token) ~= "string" then return end
    local body = {
        run_id = plan.run_id,
        outcome = tostring(report.outcome or "unknown"),
        steps_completed = tonumber(report.steps_completed) or 0,
        results = report.results or {},
    }
    local encoded_ok, encoded = pcall(function() return json.encode(body) end)
    if not encoded_ok or type(encoded) ~= "string" or #encoded > 48 * 1024 then
        encoded = json.encode({ run_id = plan.run_id, outcome = "report_encoding_error", steps_completed = 0, results = {} })
    end
    local url = "http://127.0.0.1:" .. tostring(port) .. "/api/dst/report?token=" .. token
    local ok, err = pcall(function()
        TheSim:QueryServer(url, function(response, success, code)
            if success and code == 200 then
                print("[ModXpector] GAME_REPORT_SAVED run_id=" .. tostring(plan.run_id))
            else
                print("[ModXpector] GAME_REPORT_FAILED code=" .. tostring(code))
            end
            schedule_game_poll(inst, 5)
        end, "POST", encoded, 10)
    end)
    if not ok then print("[ModXpector] GAME_REPORT_ERROR " .. tostring(err)) end
end

start_virtual_player = function(inst, plan, token, port)
    plan = plan or TEST_PLAN
    if inst == nil or inst ~= ThePlayer or TheNet == nil then return end
    local dedicated_ok, is_dedicated = pcall(function() return TheNet:IsDedicated() end)
    if not dedicated_ok or is_dedicated then return end
    if GetModConfigData("test_mode") ~= true or not is_test_mode_enabled(plan)
        or type(plan.steps) ~= "table" or #plan.steps == 0 then return end
    if virtual_player ~= nil and virtual_player.running then return end

    local VirtualPlayer = require("modxpector/virtual_player_client")
    virtual_player = VirtualPlayer.new(inst, {
        max_steps = 200,
        allowed_actions = plan.allowed_actions or {},
        allowed_prefabs = plan.allowed_prefabs or {},
        send_rpc = function(kind, request_id, value, count, x, z)
            if kind == "unlock_recipe" then
                SendModRPCToServer(MOD_RPC[MODNAME].unlock_recipe, request_id, value)
            else
                local rpc = kind == "spawn_item" and MOD_RPC[MODNAME].spawn_item or MOD_RPC[MODNAME].spawn_entity
                SendModRPCToServer(rpc, request_id, value, count, x, z)
            end
        end,
        on_finished = function(report)
            print("[ModXpector] VIRTUAL_PLAYER_FINISHED run_id=" .. tostring(plan.run_id or "none")
                .. " outcome=" .. tostring(report.outcome) .. " steps=" .. tostring(report.steps_completed))
            for _, result in ipairs(report.results or {}) do
                print("[ModXpector] step=" .. tostring(result.index) .. " status=" .. tostring(result.status)
                    .. " detail=" .. tostring(result.detail))
            end
            if token ~= nil then
                send_game_report(inst, plan, report, token, port or bridge_port)
                SendModRPCToServer(MOD_RPC[MODNAME].clear_test_plan, plan.run_id)
            end
            virtual_player = nil
        end,
    })
    local ok, err = pcall(function() virtual_player:Start(plan) end)
    if not ok then
        print("[ModXpector] Virtual Player could not start: " .. tostring(err))
        virtual_player = nil
    end
end

if type(AddClientModRPCHandler) == "function" then
    AddClientModRPCHandler(MODNAME, "action_result", function(request_id, success, message)
        if virtual_player ~= nil then virtual_player:OnRPCResult(request_id, success, message) end
    end)
    AddClientModRPCHandler(MODNAME, "plan_ready", function(run_id, success, message)
        if pending_plan == nil or pending_plan.run_id ~= run_id then return end
        if success == true then
            print("[ModXpector] GAME_TEST_PLAN_ACCEPTED run_id=" .. tostring(run_id))
            local plan = pending_plan
            pending_plan = nil
            start_virtual_player(ThePlayer, plan, bridge_token, bridge_port)
        else
            print("[ModXpector] GAME_TEST_PLAN_REJECTED reason=" .. tostring(message))
            pending_plan = nil
            schedule_game_poll(ThePlayer, 10)
        end
    end)
end

local function read_bridge_token()
    if type(io) ~= "table" or type(io.open) ~= "function" or type(MODROOT) ~= "string" then return nil end
    local read_ok, file = pcall(io.open, MODROOT .. "/bridge_token.txt", "r")
    if not read_ok or file == nil then return nil end
    local token_ok, token_value = pcall(function() return file:read("*a") end)
    pcall(function() file:close() end)
    if not token_ok or type(token_value) ~= "string" then return nil end
    local token = token_value:match("^([%w_%-]+)")
    if token == nil or #token < 32 or #token > 128 then return nil end
    return token
end



poll_game_test_plan = function(inst)
    if not bridge_poll_enabled or bridge_polling or inst == nil or inst ~= ThePlayer
        or not inst:IsValid() or pending_plan ~= nil or (virtual_player ~= nil and virtual_player.running) then return end
    if GetModConfigData("test_mode") ~= true or bridge_token == nil then return end
    bridge_polling = true
    local url = "http://127.0.0.1:" .. tostring(bridge_port) .. "/api/dst/next?token=" .. bridge_token
    local ok, err = pcall(function()
        TheSim:QueryServer(url, function(body, success, code)
            bridge_polling = false
            if not success or code ~= 200 or type(body) ~= "string" then
                print("[ModXpector] GAME_TEST_POLL_FAILED code=" .. tostring(code))
                inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
                return
            end
            local decoded_ok, payload = pcall(function() return json.decode(body) end)
            if not decoded_ok or type(payload) ~= "table" or payload.protocol ~= "modxpector-dst-bridge/v1" then
                print("[ModXpector] GAME_TEST_POLL_INVALID_RESPONSE")
                inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
                return
            end
            if type(payload.plan) == "table" then
                pending_plan = payload.plan
                local encoded_ok, encoded = pcall(function() return json.encode(pending_plan) end)
                if not encoded_ok or type(encoded) ~= "string" or #encoded > 48 * 1024 then
                    print("[ModXpector] GAME_TEST_PLAN_TOO_LARGE")
                    pending_plan = nil
                    inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
                    return
                end
                SendModRPCToServer(MOD_RPC[MODNAME].set_test_plan, pending_plan.run_id, encoded)
            else
                inst:DoTaskInTime(5, function() poll_game_test_plan(inst) end)
            end
        end, "GET", nil, 10)
    end)
    if not ok then
        bridge_polling = false
        print("[ModXpector] GAME_TEST_POLL_ERROR " .. tostring(err))
        inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
    end
end

local function send_world_inventory(inst, token, port, callback)
    local function finish(success, payload)
        if type(callback) == "function" then pcall(callback, success == true, payload) end
    end
    if inst == nil or inst ~= ThePlayer or TheSim == nil or type(TheSim.QueryServer) ~= "function" then
        finish(false, { error = "client_context_unavailable" })
        return false
    end
    if type(token) ~= "string" or token == "" then
        finish(false, { error = "local_bridge_token_missing" })
        return false
    end
    local collect_ok, inventory = pcall(WORLD_INVENTORY.Collect, _G)
    if not collect_ok or type(inventory) ~= "table" then
        print("[ModXpector] WORLD_INVENTORY_FAILED reason=collect")
        finish(false, { error = "inventory_collect_failed" })
        return false
    end
    local encode_ok, encoded = pcall(function() return json.encode(inventory) end)
    if not encode_ok or type(encoded) ~= "string" or #encoded > 48 * 1024 then
        print("[ModXpector] WORLD_INVENTORY_FAILED reason=payload_limit")
        finish(false, { error = "inventory_payload_limit" })
        return false
    end
    local url = "http://127.0.0.1:" .. tostring(port or 8765) .. "/api/dst/inventory?token=" .. token
    local ok, err = pcall(function()
        TheSim:QueryServer(url, function(body, success, code)
            if not success or code ~= 200 or type(body) ~= "string" then
                print("[ModXpector] WORLD_INVENTORY_FAILED code=" .. tostring(code))
                finish(false, { error = "http_" .. tostring(code) })
                return
            end
            local decoded_ok, payload = pcall(function() return json.decode(body) end)
            if not decoded_ok or type(payload) ~= "table" then
                print("[ModXpector] WORLD_INVENTORY_FAILED reason=invalid_response")
                finish(false, { error = "invalid_bridge_response" })
                return
            end
            local log_status = type(payload.logs) == "table" and payload.logs.status or "unavailable"
            if type(callback) == "function" then
                print("[ModXpector] WORLD_LOG_SNAPSHOT_SAVED inventory_id=" .. tostring(payload.inventory_id)
                    .. " log_status=" .. tostring(log_status))
            else
                print("[ModXpector] WORLD_INVENTORY_SAVED mods=" .. tostring(inventory.counts and inventory.counts.total_enabled or 0))
            end
            finish(true, payload)
        end, "POST", encoded, 10)
    end)
    if not ok then
        print("[ModXpector] WORLD_INVENTORY_ERROR " .. tostring(err))
        finish(false, { error = "query_error" })
        return false
    end
    return true
end

local function capture_modxpector_logs(callback)
    local function finish(success, payload)
        if type(callback) == "function" then pcall(callback, success == true, payload) end
    end
    if GetModConfigData("ai_bridge_enabled") ~= true then
        finish(false, { error = "local_bridge_disabled" })
        return false
    end
    if bridge_token == nil then bridge_token = read_bridge_token() end
    if bridge_token == nil then
        finish(false, { error = "local_bridge_token_missing" })
        return false
    end
    return send_world_inventory(ThePlayer, bridge_token, tonumber(bridge_port) or 8765, callback)
end

DST_GLOBAL.MODXPECTOR_CAPTURE_LOGS = capture_modxpector_logs

local bridge_probe_started = false
local bridge_probe_attempts = 0
local function probe_local_ai_bridge(inst)
    if bridge_probe_started or inst == nil or inst ~= ThePlayer then return end
    if GetModConfigData("ai_bridge_enabled") == false then return end
    if TheSim == nil or type(TheSim.QueryServer) ~= "function" then
        print("[ModXpector] LOCAL_AI_BRIDGE_UNAVAILABLE reason=queryserver_missing")
        return
    end
    bridge_port = tonumber(GetModConfigData("ai_bridge_port")) or 8765
    if bridge_port < 1024 or bridge_port > 65535 then bridge_port = 8765 end
    bridge_probe_started = true
    bridge_probe_attempts = bridge_probe_attempts + 1
    local function retry_probe()
        bridge_probe_started = false
        if bridge_probe_attempts < 3 and inst:IsValid() then
            inst:DoTaskInTime(15, function() probe_local_ai_bridge(inst) end)
        end
    end
    bridge_token = read_bridge_token()
    if bridge_token == nil then
        print("[ModXpector] LOCAL_AI_BRIDGE_TOKEN_MISSING")
        retry_probe()
        return
    end
    local url = "http://127.0.0.1:" .. tostring(math.floor(bridge_port))
        .. "/api/dst/health?token=" .. bridge_token
    local ok, err = pcall(function()
        TheSim:QueryServer(url, function(body, is_successful, result_code)
            if not is_successful or result_code ~= 200 or type(body) ~= "string" then
                print("[ModXpector] LOCAL_AI_BRIDGE_OFFLINE code=" .. tostring(result_code))
                retry_probe()
                return
            end
            local decoded_ok, payload = pcall(function() return json.decode(body) end)
            if not decoded_ok or type(payload) ~= "table"
                or payload.protocol ~= "modxpector-dst-bridge/v1"
                or payload.bridge ~= "ready" then
                print("[ModXpector] LOCAL_AI_BRIDGE_INVALID_RESPONSE")
                retry_probe()
                return
            end
            local agent_status = "unknown"
            if type(payload.agent) == "table" then agent_status = tostring(payload.agent.status or "unknown") end
            print("[ModXpector] LOCAL_AI_BRIDGE_READY port=" .. tostring(bridge_port) .. " agent=" .. agent_status)
            bridge_poll_enabled = true
            send_world_inventory(inst, bridge_token, bridge_port)
            if GetModConfigData("test_mode") == true then
                inst:DoTaskInTime(3, function() poll_game_test_plan(inst) end)
            else
                print("[ModXpector] Enable Test Mode in the mod configuration to allow approved live test plans")
            end
        end, "GET", nil, 10)
    end)
    if not ok then
        print("[ModXpector] LOCAL_AI_BRIDGE_ERROR " .. tostring(err))
        retry_probe()
    end
end

if type(AddPlayerPostInit) == "function" then
    AddPlayerPostInit(function(inst)
        if inst == nil or TheNet == nil then return end
        local dedicated_ok, is_dedicated = pcall(function() return TheNet:IsDedicated() end)
        if not dedicated_ok or is_dedicated then return end
        inst:DoTaskInTime(0, function()
            if inst == ThePlayer then inst:DoTaskInTime(8, function() probe_local_ai_bridge(inst) end) end
            if inst == ThePlayer and is_test_mode_enabled(TEST_PLAN) then start_virtual_player(inst, TEST_PLAN) end
        end)
    end)
end

print("[ModXpector] bootstrap loaded; test_mode=" .. tostring(GetModConfigData("test_mode") == true))

-- Restored legacy Inspector interface and input lifecycle (21.2.23).
-- The original implementation is retained as the UI layer; ModXpector's
-- current diagnostics, test runner and world inventory remain authoritative.
local GLOBAL = DST_GLOBAL
local rawget = (DST_GLOBAL and DST_GLOBAL.rawget) or rawget
local ui_pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall
local configured_key = GetModConfigData and GetModConfigData("open_key", true) or "KEY_F6"
local debug_enabled = GetModConfigData and GetModConfigData("show_debug_info", true)
local KEY_NAMES = {
    KEY_F5 = "KEY_F5", KEY_F6 = "KEY_F6", KEY_F7 = "KEY_F7",
    KEY_F8 = "KEY_F8", KEY_F9 = "KEY_F9", KEY_F10 = "KEY_F10",
}
for code = string.byte("A"), string.byte("Z") do
    local letter_key = "KEY_" .. string.char(code)
    KEY_NAMES[letter_key] = letter_key
end
local function log(message)
    print("[ModXpector UI] " .. tostring(message))
end

local MOD_NAMESPACE = "dst_mod_inspector"
local RPC_REQUEST = "request_server_report"
local RPC_RESPONSE = "server_report"
local rawset = (DST_GLOBAL and DST_GLOBAL.rawset) or rawset
local pending_events = rawget(GLOBAL, "DST_MOD_INSPECTOR_PENDING_EVENTS")
if type(pending_events) ~= "table" then
    pending_events = {}
    rawset(GLOBAL, "DST_MOD_INSPECTOR_PENDING_EVENTS", pending_events)
end
local function queue_event(kind, detail)
    if #pending_events < 32 then
        pending_events[#pending_events + 1] = { kind = kind, detail = detail }
    end
end
queue_event("modmain", MOD_VERSION .. " inicializado")
local function log_report_block(kind, content)
    print("[MODXPECTOR_EXPORT_BEGIN] " .. tostring(kind))
    for line in tostring(content or ""):gmatch("[^\n]+") do
        print("[MODXPECTOR_EXPORT_LINE] " .. line)
    end
    print("[MODXPECTOR_EXPORT_END] " .. tostring(kind))
end

local function install_server_rpc()
    if type(AddModRPCHandler) ~= "function" or type(AddClientModRPCHandler) ~= "function" then
        log("RPC API indisponível; relatório do servidor permanece no server_log.")
        return false
    end

    AddModRPCHandler(MOD_NAMESPACE, RPC_REQUEST, function(player)
        if player == nil or player.userid == nil then return end
        local world = rawget(GLOBAL, "TheWorld")
        if world == nil or world.ismastersim ~= true then return end
        local now = type(GetTime) == "function" and GetTime() or 0
        local last = player._modxpector_last_report_request or -100
        if now - last < 3 then return end
        player._modxpector_last_report_request = now

        local ok, Diagnostics = ui_pcall(require, "inspector/serverdiagnostics")
        if not ok or Diagnostics == nil then
            log("Não foi possível carregar o diagnóstico do servidor: " .. tostring(Diagnostics))
            return
        end
        local inventory_ok, WorldInventory = ui_pcall(require, "modxpector/world_inventory")
        if not inventory_ok or type(WorldInventory) ~= "table" then
            log("Inventário detalhado indisponível; mantendo diagnóstico básico: " .. tostring(WorldInventory))
            WorldInventory = nil
        end
        local collected, report = ui_pcall(Diagnostics.Collect, GLOBAL, WorldInventory)
        if not collected or type(report) ~= "table" then
            log("Falha ao coletar diagnóstico do servidor: " .. tostring(report))
            return
        end

        local ok_devtools, Devtools = ui_pcall(require, "inspector/devtools")
        if ok_devtools and Devtools ~= nil then
            if type(Devtools.SetGlobals) == "function" then Devtools.SetGlobals(GLOBAL) end
            for _, event in ipairs(pending_events) do
                Devtools.Record(event.kind, event.detail, GLOBAL)
            end
            pending_events = {}
            rawset(GLOBAL, "DST_MOD_INSPECTOR_PENDING_EVENTS", pending_events)
            Devtools.Record("server_report", "relatório solicitado", GLOBAL)
        end
        log_report_block("SERVER_DIAGNOSTICS", report.text)
        local response = Diagnostics.ToTransportString(report, 6500)
        if type(GetClientModRPC) == "function" and type(SendModRPCToClient) == "function" then
            local client_rpc = GetClientModRPC(MOD_NAMESPACE, RPC_RESPONSE)
            if client_rpc ~= nil then SendModRPCToClient(client_rpc, player.userid, response) end
        end
    end)

    AddClientModRPCHandler(MOD_NAMESPACE, RPC_RESPONSE, function(report_text)
        if type(report_text) ~= "string" then return end
        rawset(GLOBAL, "DST_MOD_INSPECTOR_SERVER_REPORT", report_text)
        log("Relatório do servidor recebido pelo cliente.")
        local frontend = rawget(GLOBAL, "TheFrontEnd")
        local active = frontend ~= nil and frontend.GetActiveScreen ~= nil and frontend:GetActiveScreen() or nil
        if active ~= nil and active.name == "ModInspectorScreen" and type(active.SetServerReport) == "function" then
            active:SetServerReport(report_text)
        end
    end)
    return true
end

local function open_inspector(from_pause_menu)
    log("Open key event received.")
    local player = rawget(GLOBAL, "ThePlayer")
    local frontend = rawget(GLOBAL, "TheFrontEnd")
    if player == nil then
        log("Open blocked: ThePlayer is nil.")
        return
    end
    if frontend == nil then
        log("Open blocked: TheFrontEnd is nil.")
        return
    end
    local active_ok, active = ui_pcall(frontend.GetActiveScreen, frontend)
    if not active_ok then
        log("Open blocked: GetActiveScreen failed: " .. tostring(active))
        return
    end
    local active_name = active ~= nil and tostring(active.name) or "<nil>"
    log("Open event context: active_screen=" .. active_name)
    if active ~= nil and active.name == "ModInspectorScreen" then
        local close_ok, close_err = ui_pcall(frontend.PopScreen, frontend)
        log(close_ok and "Dashboard close requested." or ("Dashboard close failed: " .. tostring(close_err)))
        return
    end
    if active == nil or (active.name ~= "HUD" and not (from_pause_menu and active.name == "PauseScreen")) then
        log("Open blocked: expected HUD or pause menu entry; got " .. active_name)
        return
    end
    local ok, Screen = ui_pcall(require, "screens/modinspectorscreen")
    if not ok or Screen == nil then
        log("Could not load dashboard: " .. tostring(Screen))
        return
    end
    local runtime_config = CONFIG_SNAPSHOT.Read(GetModConfigData, pcall)
    local create_ok, screen = ui_pcall(Screen, GLOBAL, debug_enabled ~= false, runtime_config)
    if not create_ok or screen == nil then
        log("Could not construct dashboard: " .. tostring(screen))
        return
    end
    local push_ok, push_err = ui_pcall(frontend.PushScreen, frontend, screen)
    if not push_ok then
        log("Could not push dashboard: " .. tostring(push_err))
        return
    end
    log("Dashboard pushed successfully.")
end

local key_handler_installed = false

local function install_client_key()
    if key_handler_installed then
        return true
    end
    local player = rawget(GLOBAL, "ThePlayer")
    local the_input = rawget(GLOBAL, "TheInput")
    if player == nil or the_input == nil
        or type(the_input.AddKeyDownHandler) ~= "function" then
        return
    end
    local configured = configured_key
    local key_name = KEY_NAMES[configured]
    if key_name == nil then
        log("Unsupported configured key " .. tostring(configured) .. "; using KEY_F6 fallback.")
        key_name = "KEY_F6"
    end
    local key = rawget(GLOBAL, key_name)
    if key == nil then
        log("Configured key constant unavailable: " .. tostring(key_name))
        return
    end
    the_input:AddKeyDownHandler(key, open_inspector)
    key_handler_installed = true
    log("Client dashboard key handler registered; configured=" .. tostring(configured) .. ", constant=" .. key_name .. ", value=" .. tostring(key))
    return true
end


install_server_rpc()
log("legacy Inspector interface and server-report RPC initialized.")
local function on_runtime_ready()
    local world = rawget(GLOBAL, "TheWorld")
    if world ~= nil and world.ismastersim == true then
        -- Full mod/dependency/registry scans are intentionally user-triggered.
        queue_event("sim_ready", "simulação mestre pronta; diagnósticos completos aguardam solicitação")
        log("Master simulation ready; full diagnostics deferred until requested.")
    end
    install_client_key() -- best-effort; ThePlayer may not exist yet on clients
end

if AddSimPostInit then
    AddSimPostInit(on_runtime_ready)
elseif AddGamePostInit then
    AddGamePostInit(on_runtime_ready)
end

-- The simulation post-init can run before the local player/HUD exists. Retry at
-- player creation and, most importantly, when the local PlayerHUD is constructed.
-- Client key installation is attached to PlayerHUD construction below.
if AddClassPostConstruct then
    AddClassPostConstruct("screens/playerhud", function()
        install_client_key()
    end)

    -- Add a native Redux pause-menu entry. AddItem is the supported menu API;
    -- keep the callback isolated so other pause-menu mods remain untouched.
    AddClassPostConstruct("screens/redux/pausescreen", function(self)
        if self == nil or self.menu == nil or self._modxpector_pause_entry then
            return
        end
        local menu = self.menu
        if type(menu.AddItem) ~= "function" then
            log("Pause menu integration skipped: menu:AddItem unavailable.")
            return
        end
        local ok, err = ui_pcall(menu.AddItem, menu, "ModXpector", function()
            open_inspector(true)
        end)
        if ok then
            self._modxpector_pause_entry = true
            log("Pause menu entry registered.")
        else
            log("Pause menu entry failed: " .. tostring(err))
        end
    end)
end
