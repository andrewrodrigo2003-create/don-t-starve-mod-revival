-- DST runs modmain in a restricted environment where pcall may not be
-- exposed as a direct global. Use the engine global table explicitly.
local DST_GLOBAL = GLOBAL or _G
local pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall
local MODNAME = modname or "modxpector"
local MOD_VERSION = "5.0.14-dev"
local INVENTORY_OK, WORLD_INVENTORY = pcall(require, "modxpector/world_inventory")
local INVENTORY_LOAD_ERROR
if not INVENTORY_OK then
    INVENTORY_LOAD_ERROR = tostring(WORLD_INVENTORY)
elseif type(WORLD_INVENTORY) ~= "table" or type(WORLD_INVENTORY.Collect) ~= "function" then
    INVENTORY_LOAD_ERROR = "module returned an invalid inventory interface"
    INVENTORY_OK = false
end
if not INVENTORY_OK then
    print("[ModXpector] WORLD_INVENTORY_MODULE_LOAD_FAILED " .. tostring(INVENTORY_LOAD_ERROR))
    WORLD_INVENTORY = nil
end
local RUNTIME_OBSERVER_OK, RUNTIME_OBSERVER = pcall(require, "modxpector/runtime_observer")
if not RUNTIME_OBSERVER_OK or type(RUNTIME_OBSERVER) ~= "table"
    or type(RUNTIME_OBSERVER.Register) ~= "function"
    or type(RUNTIME_OBSERVER.Snapshot) ~= "function" then
    print("[ModXpector] RUNTIME_OBSERVER_MODULE_UNAVAILABLE " .. tostring(RUNTIME_OBSERVER))
    RUNTIME_OBSERVER_OK = false
    RUNTIME_OBSERVER = nil
end

local runtime_component_observation_enabled = false
if type(GetModConfigData) == "function" then
    local config_ok, config_value = pcall(GetModConfigData, "collect_runtime_components")
    runtime_component_observation_enabled = config_ok and config_value == true
end
if RUNTIME_OBSERVER_OK then
    local register_call_ok, observer_available = pcall(RUNTIME_OBSERVER.Register,
        AddComponentPostInit, DST_GLOBAL, runtime_component_observation_enabled, pcall, GetTime)
    if not register_call_ok then
        print("[ModXpector] RUNTIME_COMPONENT_OBSERVER_REGISTER_FAILED " .. tostring(observer_available))
    elseif runtime_component_observation_enabled then
        print("[ModXpector] RUNTIME_COMPONENT_OBSERVER enabled=true available="
            .. tostring(observer_available == true))
    end
end
local COMMUNITY_EVENTS_OK, COMMUNITY_EVENTS = pcall(require, "modxpector/community_events")
if not COMMUNITY_EVENTS_OK or type(COMMUNITY_EVENTS) ~= "table"
    or type(COMMUNITY_EVENTS.Configure) ~= "function"
    or type(COMMUNITY_EVENTS.Report) ~= "function"
    or type(COMMUNITY_EVENTS.Snapshot) ~= "function" then
    print("[ModXpector] COMMUNITY_EVENT_MODULE_UNAVAILABLE " .. tostring(COMMUNITY_EVENTS))
    COMMUNITY_EVENTS_OK = false
    COMMUNITY_EVENTS = nil
end

local community_event_ingestion_enabled = false
if type(GetModConfigData) == "function" then
    local config_ok, config_value = pcall(GetModConfigData, "accept_community_events")
    community_event_ingestion_enabled = config_ok and config_value == true
end
local COMMUNITY_EVENTS_CONFIGURED = false
if COMMUNITY_EVENTS_OK then
    local configure_ok, configure_error = pcall(COMMUNITY_EVENTS.Configure,
        community_event_ingestion_enabled, GetTime)
    COMMUNITY_EVENTS_CONFIGURED = configure_ok
    if not configure_ok then
        print("[ModXpector] COMMUNITY_EVENT_CONFIGURE_FAILED " .. tostring(configure_error))
    end
end

local function report_community_diagnostic_event(event)
    if not COMMUNITY_EVENTS_OK or not COMMUNITY_EVENTS_CONFIGURED then
        return false, "community_event_module_unavailable"
    end
    local report_ok, accepted, event_id, status = pcall(COMMUNITY_EVENTS.Report, event)
    if not report_ok then return false, "invalid_community_event_payload" end
    return accepted, event_id, status
end
DST_GLOBAL.MODXPECTOR_REPORT_DIAGNOSTIC_EVENT = report_community_diagnostic_event

local EMBEDDED_AI_OK, EMBEDDED_AI = pcall(require, "modxpector/embedded_ai")
if not EMBEDDED_AI_OK or type(EMBEDDED_AI) ~= "table" or type(EMBEDDED_AI.Analyze) ~= "function" then
    print("[ModXpector] EMBEDDED_AI_MODULE_LOAD_FAILED " .. tostring(EMBEDDED_AI))
    EMBEDDED_AI_OK = false
    EMBEDDED_AI = nil
end
local CHAT_COMMANDS_OK, CHAT_COMMANDS = pcall(require, "modxpector/chat_commands")
if not CHAT_COMMANDS_OK or type(CHAT_COMMANDS) ~= "table" or type(CHAT_COMMANDS.Parse) ~= "function" then
    print("[ModXpector] CHAT_COMMAND_PARSER_UNAVAILABLE " .. tostring(CHAT_COMMANDS))
    CHAT_COMMANDS_OK = false
    CHAT_COMMANDS = nil
end
local PLAN_OK, TEST_PLAN = pcall(require, "modxpector/test_plan")
if not PLAN_OK or type(TEST_PLAN) ~= "table" then
    TEST_PLAN = { schema = "modxpector/test-plan/v1", enabled = false, allowed_prefabs = {}, allowed_recipes = {}, allowed_actions = {}, steps = {} }
end
local CONFIG_SNAPSHOT_OK, CONFIG_SNAPSHOT = pcall(require, "inspector/config_snapshot")
if not CONFIG_SNAPSHOT_OK or type(CONFIG_SNAPSHOT) ~= "table" or type(CONFIG_SNAPSHOT.Read) ~= "function" then
    CONFIG_SNAPSHOT = { Read = function() return {
        open_key = "KEY_F6", show_debug_info = true,
        test_mode = false, laboratory_mode = false, collect_runtime_components = false, max_spawn_count = 10,
    } end }
end

local embedded_ai_session = EMBEDDED_AI_OK and EMBEDDED_AI.NewSession("world-session") or nil
local embedded_ai_test_suites = {}
local function register_embedded_test_suite(suite)
    if not EMBEDDED_AI_OK then return false, "embedded_ai_unavailable" end
    local valid, normalized = EMBEDDED_AI.ValidateSuite(suite)
    if not valid then return false, tostring(normalized) end
    if #embedded_ai_test_suites >= 128 then return false, "suite_registry_limit" end
    local key = normalized.owner_mod_id .. "|" .. normalized.id
    for _, existing in ipairs(embedded_ai_test_suites) do
        if existing.owner_mod_id .. "|" .. existing.id == key then
            return false, "duplicate_suite"
        end
    end
    embedded_ai_test_suites[#embedded_ai_test_suites + 1] = normalized
    return true, "registered"
end

DST_GLOBAL.MODXPECTOR_TEST_SUITE_API_VERSION = 1
DST_GLOBAL.MODXPECTOR_REGISTER_TEST_SUITE = register_embedded_test_suite

local function set_embedded_ai_status(status, detail, summary)
    local state = {
        status = tostring(status or "unknown"),
        detail = tostring(detail or ""),
        summary = type(summary) == "table" and summary or {},
    }
    if type(DST_GLOBAL.rawset) == "function" then
        DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_STATUS", state)
    else
        DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_STATUS = state
    end
end

set_embedded_ai_status(EMBEDDED_AI_OK and "pronta" or "indisponivel",
    EMBEDDED_AI_OK and "Motor simbólico embarcado; sem serviço externo." or "Módulo de IA embarcada indisponível.")

local function run_embedded_ai_diagnostics(callback)
    local function finish(success, message, report)
        if type(callback) == "function" then pcall(callback, success == true, tostring(message or ""), report) end
    end
    if not EMBEDDED_AI_OK then
        set_embedded_ai_status("indisponivel", "O módulo embarcado não foi carregado.")
        finish(false, "Motor de IA embarcada indisponível.")
        return false
    end
    if not INVENTORY_OK or type(WORLD_INVENTORY) ~= "table" or type(WORLD_INVENTORY.Collect) ~= "function" then
        set_embedded_ai_status("inventario_indisponivel", tostring(INVENTORY_LOAD_ERROR or "Inventário indisponível."))
        finish(false, "Não foi possível coletar o inventário de mods.")
        return false
    end
    local collect_ok, snapshot = pcall(WORLD_INVENTORY.Collect, DST_GLOBAL)
    if collect_ok and type(snapshot) == "table" then
        if RUNTIME_OBSERVER_OK then
            local observer_ok, observer_snapshot = pcall(RUNTIME_OBSERVER.Snapshot, DST_GLOBAL)
            if observer_ok and type(observer_snapshot) == "table" then
                if runtime_component_observation_enabled and observer_snapshot.enabled ~= true then
                    observer_snapshot.enabled = true
                    observer_snapshot.available = false
                    observer_snapshot.reason = observer_snapshot.reason or "registration_failed"
                end
                snapshot.runtime_components = observer_snapshot
            end
        end
        if snapshot.runtime_components == nil then
            snapshot.runtime_components = {
                schema = "modxpector/runtime-component-observations/v1",
                enabled = runtime_component_observation_enabled,
                available = false,
                components = {},
                events = {},
                reason = RUNTIME_OBSERVER_OK and "observer_snapshot_unavailable" or "observer_module_unavailable",
            }
        end
        if COMMUNITY_EVENTS_OK and COMMUNITY_EVENTS_CONFIGURED then
            local events_ok, event_snapshot = pcall(COMMUNITY_EVENTS.Snapshot)
            if events_ok and type(event_snapshot) == "table" then
                snapshot.community_events = event_snapshot
            end
        end
        if snapshot.community_events == nil then
            snapshot.community_events = {
                schema = "modxpector/community-diagnostic-events/v1",
                enabled = community_event_ingestion_enabled,
                available = false,
                events = {},
                event_count = 0,
                dropped = 0,
                reason = COMMUNITY_EVENTS_OK and COMMUNITY_EVENTS_CONFIGURED
                    and "event_snapshot_unavailable" or "event_module_unavailable",
            }
        end
    end
    if not collect_ok or type(snapshot) ~= "table" then
        set_embedded_ai_status("falha_coleta", tostring(snapshot))
        finish(false, "Falha ao observar os mods ativos.")
        return false
    end
    local analyze_ok, analysis = pcall(EMBEDDED_AI.Analyze, snapshot)
    if not analyze_ok or type(analysis) ~= "table" then
        set_embedded_ai_status("falha_analise", tostring(analysis))
        finish(false, "Falha no motor de diagnóstico embarcado.")
        return false
    end
    local plan_ok, plan = pcall(EMBEDDED_AI.BuildPlan, analysis)
    if not plan_ok or type(plan) ~= "table" then
        set_embedded_ai_status("falha_planejamento", tostring(plan))
        finish(false, "Falha ao priorizar a investigação.")
        return false
    end
    local task_execution = EMBEDDED_AI.RunReadOnlyPlan(plan, embedded_ai_session, snapshot, 200)
    local next_task = task_execution.next_task
    local candidate_suites = EMBEDDED_AI.GetBuiltinSuites()
    for _, suite in ipairs(embedded_ai_test_suites) do
        candidate_suites[#candidate_suites + 1] = suite
    end
    local selected_suites = EMBEDDED_AI.SelectSuites(candidate_suites, snapshot, DST_GLOBAL.Prefabs)
    local report = {
        schema = "modxpector/embedded-ai-report/v1",
        snapshot = snapshot,
        analysis = analysis,
        plan = plan,
        next_task = next_task,
        task_execution = task_execution,
        runtime_components = snapshot.runtime_components,
        community_events = snapshot.community_events,
        session = embedded_ai_session,
        selected_suites = selected_suites,
    }
    if type(DST_GLOBAL.rawset) == "function" then
        DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_REPORT", report)
    else
        DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_REPORT = report
    end
    local summary = analysis.summary or {}
    set_embedded_ai_status("analisada", tostring(analysis.statement or "Análise concluída."), summary)
    print("[ModXpector] EMBEDDED_AI_ANALYSIS status=" .. tostring(analysis.status)
        .. " decision=" .. tostring(analysis.decision)
        .. " findings=" .. tostring(summary.total or 0)
        .. " tasks=" .. tostring(plan.total or 0)
        .. " executed=" .. tostring(task_execution.executed or 0)
        .. " suites=" .. tostring(#selected_suites))
    for index, finding in ipairs(analysis.findings or {}) do
        if index > 8 then break end
        print("[ModXpector] AI_FINDING code=" .. tostring(finding.code)
            .. " mod=" .. tostring(finding.mod_id)
            .. " confidence=" .. tostring(finding.confidence))
    end
    if next_task ~= nil then
        print("[ModXpector] EMBEDDED_AI_NEXT_TASK kind=" .. tostring(next_task.kind)
            .. " mod=" .. tostring(next_task.mod_id))
    end
    finish(true, "Análise concluída: " .. tostring(summary.total or 0)
        .. " achado(s), " .. tostring(plan.total or 0) .. " tarefa(s) de investigação.", report)
    return true
end

DST_GLOBAL.MODXPECTOR_RUN_EMBEDDED_AI = run_embedded_ai_diagnostics

local active_test_plan = nil
local function current_test_plan()
    return active_test_plan or TEST_PLAN
end

local function consume_declared_server_operation(plan, step_index, run_id, kind, value, count)
    if active_test_plan == nil or plan ~= active_test_plan then
        return false, "there is no active Master-approved test plan"
    end
    if type(run_id) ~= "string" or plan.run_id ~= run_id then
        return false, "stale or mismatched test run ID"
    end
    if not integer_in_range(step_index, 1, #plan.steps) then
        return false, "invalid test plan step index"
    end
    if type(plan._server_consumed_steps) ~= "table" then
        return false, "server-side plan authorization state is unavailable"
    end
    if plan._server_consumed_steps[step_index] == true then
        return false, "test plan step was already consumed"
    end

    local step = plan.steps[step_index]
    if type(step) ~= "table" or step.kind ~= kind then
        return false, "RPC operation does not match the declared test plan step"
    end
    if kind == "unlock_recipe" then
        if step.recipe ~= value then return false, "recipe does not match the declared test plan step" end
    elseif kind == "spawn_item" or kind == "spawn_entity" then
        local expected_count = step.count == nil and 1 or step.count
        if step.prefab ~= value or expected_count ~= count then
            return false, "spawn request does not match the declared test plan step"
        end
    else
        return false, "unsupported server operation kind"
    end

    plan._server_consumed_steps[step_index] = true
    return true, "authorized"
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

local SERVER_ACTION_ALLOWLIST = {
    ATTACK = true, CHOP = true, MINE = true, DIG = true, HAMMER = true,
    PICK = true, HARVEST = true, PICKUP = true, TILL = true, REPAIR = true,
    WALKTO = true, EAT = true, USEITEM = true, CASTAOE = true, CASTSPELL = true,
    RUMMAGE = true, DISMOUNT = true, MOUNT = true, TALKTO = true, DEPLOY = true,
    PLANT = true, EQUIP = true, UNEQUIP = true, GIVE = true, DROP = true,
    COOK = true, READ = true, SADDLE = true, FISH = true, CATCH = true,
    LIGHT = true, EXTINGUISH = true, SLEEPIN = true, TURNON = true, TURNOFF = true,
    ACTIVATE = true, OPEN = true, CLOSE = true, STORE = true, TAKEITEM = true, TAKESINGLEITEM = true,
}
local AI_ACTION_ALLOWLIST = { WALKTO = true }
local ASSERTION_ALLOWLIST = {
    player_health_gte = true, player_hunger_gte = true, player_sanity_gte = true,
    player_has_item = true, player_has_item_count_gte = true, player_inventory_has_item = true, container_has_item = true, player_equipped = true,
    player_near_target = true, player_knows_recipe = true,
    target_exists = true, target_health_lte = true, target_dead = true, target_has_tag = true,
}
local TARGET_ASSERTION_ALLOWLIST = {
    player_near_target = true, target_exists = true, target_health_lte = true,
    target_dead = true, target_has_tag = true, container_has_item = true,
}
local SIDE_EFFECT_STEP_ALLOWLIST = {
    action = true, craft = true, craft_at_point = true,
    unlock_recipe = true, spawn_item = true, spawn_entity = true,
}

local function plan_requires_laboratory(plan)
    if type(plan) ~= "table" or type(plan.steps) ~= "table" then return false end
    for _, step in ipairs(plan.steps) do
        if type(step) == "table" then
            if step.kind == "action" then
                -- WALKTO still moves the real local player; it is not observation-only.
                return true
            end
            if step.kind == "craft" or step.kind == "craft_at_point"
                or step.kind == "unlock_recipe" or step.kind == "spawn_item"
                or step.kind == "spawn_entity" then
                return true
            end
        end
    end
    return false
end

local function laboratory_mode_enabled()
    return type(GetModConfigData) == "function"
        and GetModConfigData("laboratory_mode") == true
end

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function integer_in_range(value, minimum, maximum)
    return finite_number(value) and value == math.floor(value)
        and value >= minimum and value <= maximum
end

local function safe_tag(value)
    return type(value) == "string" and #value >= 1 and #value <= 64
        and value:match("^[%w_%-]+$") ~= nil
end

local function safe_tag_list(value)
    if value == nil then return true end
    if type(value) == "string" then return safe_tag(value) end
    if type(value) ~= "table" or #value > 32 then return false end
    for _, tag in ipairs(value) do
        if not safe_tag(tag) then return false end
    end
    return true
end

local function valid_target_selector(selector, plan)
    if type(selector) ~= "table" or not prefab_is_allowed(selector.prefab, plan) then return false end
    if selector.radius ~= nil and (not finite_number(selector.radius)
        or selector.radius < 1 or selector.radius > 40) then return false end
    if selector.tag ~= nil and not safe_tag(selector.tag) then return false end
    return safe_tag_list(selector.tags) and safe_tag_list(selector.notags)
        and safe_tag_list(selector.oneoftags)
end

local function valid_position(position)
    return type(position) == "table"
        and finite_number(position.x) and finite_number(position.z)
        and math.abs(position.x) <= 100000 and math.abs(position.z) <= 100000
        and (position.y == nil or finite_number(position.y))
end

local function validate_postcondition_reference(plan, index, reference)
    if not integer_in_range(reference, 1, index - 1) then
        return false, "invalid postcondition reference"
    end
    local previous = plan.steps[reference]
    if type(previous) ~= "table" or SIDE_EFFECT_STEP_ALLOWLIST[previous.kind] ~= true then
        return false, "postcondition must reference a previous side-effect step"
    end
    return true
end

local function validate_target_reference(plan, index, reference)
    if not integer_in_range(reference, 1, index - 1) then
        return false, "invalid target_step reference"
    end
    local previous = plan.steps[reference]
    if type(previous) ~= "table" or previous.kind ~= "action"
        or previous.target_required ~= true or type(previous.target) ~= "table" then
        return false, "target_step must reference a previous action with a target selector"
    end
    return true
end

local function validate_plan_assertion(plan, index, step)
    local assertion = step.assertion
    if type(assertion) ~= "table" or ASSERTION_ALLOWLIST[assertion.kind] ~= true then
        return false, "unsupported assertion kind"
    end
    if assertion.expected ~= nil and type(assertion.expected) ~= "boolean" then
        return false, "assertion expected must be boolean"
    end
    if assertion.kind == "player_health_gte" or assertion.kind == "player_hunger_gte"
        or assertion.kind == "player_sanity_gte" or assertion.kind == "target_health_lte" then
        if not finite_number(assertion.value) or assertion.value < 0 or assertion.value > 100000 then
            return false, "invalid assertion numeric value"
        end
    elseif assertion.kind == "player_has_item" or assertion.kind == "player_has_item_count_gte"
        or assertion.kind == "player_inventory_has_item" or assertion.kind == "container_has_item"
        or assertion.kind == "player_equipped" then
        if not prefab_is_allowed(assertion.prefab, plan) then
            return false, "assertion prefab is not in the plan allowlist"
        end
        if assertion.kind == "player_has_item_count_gte"
            and not integer_in_range(assertion.count, 1, 10000) then
            return false, "inventory assertion count must be an integer from 1 to 10000"
        elseif assertion.kind == "container_has_item" and assertion.count ~= nil
            and not integer_in_range(assertion.count, 1, 10000) then
            return false, "container assertion count must be an integer from 1 to 10000"
        end
        if assertion.kind == "player_equipped" and (type(assertion.slot) ~= "string"
            or #assertion.slot < 1 or #assertion.slot > 32
            or (type(EQUIPSLOTS) == "table" and EQUIPSLOTS[assertion.slot] == nil)) then
            return false, "invalid equipment slot"
        end
    elseif assertion.kind == "player_knows_recipe" then
        if not recipe_is_allowed(assertion.recipe, plan) then
            return false, "assertion recipe is not in the plan allowlist"
        end
    elseif assertion.kind == "player_near_target" then
        if assertion.radius ~= nil and (not finite_number(assertion.radius)
            or assertion.radius < 0 or assertion.radius > 100) then
            return false, "invalid target distance radius"
        end
    elseif assertion.kind == "target_has_tag" then
        if not safe_tag(assertion.tag) then return false, "invalid target tag" end
    end

    if TARGET_ASSERTION_ALLOWLIST[assertion.kind] then
        if assertion.target_step ~= nil then
            if assertion.target ~= nil then return false, "use target or target_step, not both" end
            local ok, reason = validate_target_reference(plan, index, assertion.target_step)
            if not ok then return false, reason end
        elseif not valid_target_selector(assertion.target, plan) then
            return false, "invalid target selector"
        end
    elseif assertion.target_step ~= nil or assertion.target ~= nil then
        return false, "this assertion does not accept a target selector"
    end

    if step.verifies_step ~= nil and step.verifies_steps ~= nil then
        return false, "use verifies_step or verifies_steps, not both"
    end
    if step.verifies_step ~= nil then
        return validate_postcondition_reference(plan, index, step.verifies_step)
    elseif step.verifies_steps ~= nil then
        if type(step.verifies_steps) ~= "table" or #step.verifies_steps < 1 or #step.verifies_steps > 20 then
            return false, "verifies_steps must contain 1 to 20 references"
        end
        local seen = {}
        for _, reference in ipairs(step.verifies_steps) do
            if seen[reference] then return false, "duplicate verifies_steps reference" end
            seen[reference] = true
            local ok, reason = validate_postcondition_reference(plan, index, reference)
            if not ok then return false, reason end
        end
    end
    return true
end

local function validate_plan_step(plan, index, step)
    if type(step) ~= "table" then return false, "step must be an object" end
    if step.kind ~= "assert" and (step.verifies_step ~= nil or step.verifies_steps ~= nil) then
        return false, "only assertion steps may verify side effects"
    end
    if step.skin ~= nil and (type(step.skin) ~= "string" or #step.skin > 128
        or not step.skin:match("^[%w_%-]+$")) then
        return false, "invalid skin identifier"
    end
    if step.timeout ~= nil and (not finite_number(step.timeout) or step.timeout < 1 or step.timeout > 120) then
        return false, "invalid step timeout"
    end
    if step.kind == "wait" then
        local seconds = step.seconds == nil and 1 or step.seconds
        return finite_number(seconds) and seconds >= 0 and seconds <= 120,
            "invalid wait duration"
    elseif step.kind == "action" then
        if type(step.action) ~= "string"
            or (SERVER_ACTION_ALLOWLIST[step.action] ~= true and not contains_value(plan.allowed_actions, step.action)) then
            return false, "action is not in the server allowlist"
        end
        if step.target ~= nil and not valid_target_selector(step.target, plan) then
            return false, "invalid action target selector"
        end
        if step.target_required ~= nil and type(step.target_required) ~= "boolean" then
            return false, "target_required must be boolean"
        end
        if step.target_required == true and step.target == nil then
            return false, "target_required action needs a target selector"
        end
        if step.invobject ~= nil and not prefab_is_allowed(step.invobject, plan) then
            return false, "action inventory object is not in the plan allowlist"
        end
        if step.position ~= nil and not valid_position(step.position) then
            return false, "invalid action position"
        end
        if step.repeat_until_target_dead ~= nil and type(step.repeat_until_target_dead) ~= "boolean" then
            return false, "repeat_until_target_dead must be boolean"
        end
        if step.repeat_until_target_dead == true then
            local repeat_timeout = step.repeat_timeout == nil and 120 or step.repeat_timeout
            if step.action ~= "ATTACK" or step.target_required ~= true
                or not valid_target_selector(step.target, plan)
                or not integer_in_range(step.max_repeats, 1, 20)
                or not finite_number(repeat_timeout) or repeat_timeout < 1 or repeat_timeout > 600 then
                return false, "invalid bounded attack repeat configuration"
            end
        elseif step.max_repeats ~= nil or step.repeat_timeout ~= nil then
            return false, "repeat limits require repeat_until_target_dead"
        end
        return true
    elseif step.kind == "craft" or step.kind == "craft_at_point" or step.kind == "unlock_recipe" then
        if not recipe_is_allowed(step.recipe, plan) then return false, "recipe is not in the plan allowlist" end
        if step.kind == "craft_at_point" then
            if not valid_position(step.position) then return false, "invalid placer position" end
            if step.rotation ~= nil and (not finite_number(step.rotation) or math.abs(step.rotation) > 360) then
                return false, "invalid placer rotation"
            end
        end
        return true
    elseif step.kind == "spawn_item" or step.kind == "spawn_entity" then
        if not prefab_is_allowed(step.prefab, plan) then return false, "spawn prefab is not in the plan allowlist" end
        local count = step.count == nil and 1 or step.count
        if not integer_in_range(count, 1, 20) then return false, "invalid spawn count" end
        if step.position ~= nil and not valid_position(step.position) then return false, "invalid spawn position" end
        return true
    elseif step.kind == "assert" then
        return validate_plan_assertion(plan, index, step)
    end
    return false, "unsupported test step kind"
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
    for index, step in ipairs(plan.steps) do
        local valid, reason = validate_plan_step(plan, index, step)
        if not valid then return false, "step " .. tostring(index) .. ": " .. tostring(reason) end
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

local function get_max_spawn_count()
    local configured = tonumber(GetModConfigData("max_spawn_count"))
    if configured ~= 5 and configured ~= 10 and configured ~= 20 then
        return 10
    end
    return configured
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
    if plan_requires_laboratory(plan) and not laboratory_mode_enabled() then
        reply(false, "laboratory mode is disabled; world-changing steps require a separate disposable test world")
        return
    end
    plan._server_consumed_steps = {}
    active_test_plan = plan
    reply(true, "test plan accepted by master simulation")
end

local function handle_unlock_recipe(player, request_id, step_index, run_id, recipe_name)
    if TheWorld == nil or not TheWorld.ismastersim then return end
    local plan = current_test_plan()
    if not is_test_mode_enabled(plan) then send_result(player, request_id, false, "test mode disabled"); return end
    if not laboratory_mode_enabled() then
        send_result(player, request_id, false, "laboratory mode is disabled; recipe changes require a disposable test world")
        return
    end
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
    local authorized, authorization_reason = consume_declared_server_operation(
        plan, step_index, run_id, "unlock_recipe", recipe_name)
    if not authorized then
        send_result(player, request_id, false, authorization_reason)
        return
    end
    local ok, err = pcall(function() player.components.builder:UnlockRecipe(recipe_name) end)
    send_result(player, request_id, ok, ok and ("unlocked recipe " .. recipe_name) or tostring(err))
end

local function handle_spawn(player, request_id, step_index, run_id, prefab, count, x, z, as_item)
    if TheWorld == nil or not TheWorld.ismastersim then return end
    local plan = current_test_plan()
    if not is_test_mode_enabled(plan) then send_result(player, request_id, false, "test mode disabled"); return end
    if not laboratory_mode_enabled() then
        send_result(player, request_id, false, "laboratory mode is disabled; spawning requires a disposable test world")
        return
    end
    if not is_admin_player(player) then send_result(player, request_id, false, "administrator permission required"); return end
    if not allow_spawn_request(player) then send_result(player, request_id, false, "test spawn rate limit exceeded"); return end
    count = tonumber(count)
    if not prefab_is_allowed(prefab, plan) or type(count) ~= "number" or count ~= math.floor(count)
        or count < 1 or count > get_max_spawn_count() then
        send_result(player, request_id, false, "prefab or spawn count is outside the test plan allowlist or configured limit")
        return
    end
    x, z = tonumber(x), tonumber(z)
    if x == nil or z == nil or x ~= x or z ~= z or math.abs(x) > 100000 or math.abs(z) > 100000 then
        send_result(player, request_id, false, "invalid spawn coordinates")
        return
    end
    local operation_kind = as_item and "spawn_item" or "spawn_entity"
    local authorized, authorization_reason = consume_declared_server_operation(
        plan, step_index, run_id, operation_kind, prefab, count)
    if not authorized then
        send_result(player, request_id, false, authorization_reason)
        return
    end
    local spawned = 0
    local delivered = 0
    local inventory_rejected = 0
    for _ = 1, count do
        local spawn_ok, entity = pcall(SpawnPrefab, prefab)
        local valid_ok, entity_valid = false, false
        if spawn_ok and entity ~= nil and type(entity.IsValid) == "function" then
            valid_ok, entity_valid = pcall(entity.IsValid, entity)
        end
        if spawn_ok and valid_ok and entity_valid == true then
            spawned = spawned + 1
            if as_item then
                local inventory = player.components ~= nil and player.components.inventory or nil
                local give_ok, give_result = false, nil
                if inventory ~= nil and type(inventory.GiveItem) == "function" then
                    give_ok, give_result = pcall(inventory.GiveItem, inventory, entity)
                end
                if give_ok and give_result ~= false and give_result ~= nil then
                    delivered = delivered + 1
                else
                    inventory_rejected = inventory_rejected + 1
                    local still_valid_ok, still_valid = pcall(entity.IsValid, entity)
                    if still_valid_ok and still_valid == true and entity.Transform ~= nil
                        and type(entity.Transform.SetPosition) == "function" then
                        pcall(entity.Transform.SetPosition, entity.Transform, x, 0, z)
                    end
                end
            elseif entity.Transform ~= nil and type(entity.Transform.SetPosition) == "function" then
                local position_ok = pcall(entity.Transform.SetPosition, entity.Transform, x, 0, z)
                if position_ok then delivered = delivered + 1 end
            end
        end
    end
    local complete = spawned == count and (not as_item or delivered == count)
        and (as_item or delivered == spawned)
    local message
    if as_item then
        message = "created " .. tostring(spawned) .. "/" .. tostring(count)
            .. "; delivered " .. tostring(delivered) .. " to inventory"
            .. (inventory_rejected > 0 and ("; inventory rejected " .. tostring(inventory_rejected)) or "")
    else
        message = "spawned " .. tostring(delivered) .. "/" .. tostring(count) .. " entities"
    end
    send_result(player, request_id, complete, message)
end

if type(AddModRPCHandler) == "function" then
    AddModRPCHandler(MODNAME, "set_test_plan", handle_set_test_plan)
    AddModRPCHandler(MODNAME, "clear_test_plan", function(player, run_id)
        if TheWorld == nil or not TheWorld.ismastersim or not is_admin_player(player) then return end
        if active_test_plan ~= nil and active_test_plan.run_id == run_id then active_test_plan = nil end
    end)
    AddModRPCHandler(MODNAME, "spawn_item", function(player, request_id, step_index, run_id, prefab, count, x, z)
        handle_spawn(player, request_id, step_index, run_id, prefab, count, x, z, true)
    end)
    AddModRPCHandler(MODNAME, "spawn_entity", function(player, request_id, step_index, run_id, prefab, count, x, z)
        handle_spawn(player, request_id, step_index, run_id, prefab, count, x, z, false)
    end)
    AddModRPCHandler(MODNAME, "unlock_recipe", handle_unlock_recipe)
end

local virtual_player
local start_virtual_player
local pending_ai_plan

local function record_embedded_suite_result(plan, status, evidence)
    if not EMBEDDED_AI_OK or embedded_ai_session == nil or type(plan) ~= "table"
        or type(plan.suite_id) ~= "string" or type(plan.scenario_id) ~= "string" then return end
    local task_id = "suite-" .. plan.suite_id .. "-" .. plan.scenario_id .. "-" .. tostring(plan.run_id or "unknown")
    EMBEDDED_AI.RecordTaskResult(embedded_ai_session, task_id, status, evidence)
    local result = { suite_id = plan.suite_id, scenario_id = plan.scenario_id, status = status, evidence = evidence or {} }
    if type(DST_GLOBAL.rawset) == "function" then
        DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_LAST_SUITE_RESULT", result)
        DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_SESSION", embedded_ai_session)
    else
        DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_LAST_SUITE_RESULT = result
        DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_SESSION = embedded_ai_session
    end
    local current_report = DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_REPORT
    if type(current_report) == "table" then
        current_report.session = embedded_ai_session
        current_report.last_suite_result = result
    end
end

start_virtual_player = function(inst, plan)
    plan = plan or TEST_PLAN
    if inst == nil or inst ~= ThePlayer or TheNet == nil then return false end
    local dedicated_ok, is_dedicated = pcall(function() return TheNet:IsDedicated() end)
    if not dedicated_ok or is_dedicated then return false end
    if GetModConfigData("test_mode") ~= true or not is_test_mode_enabled(plan)
        or type(plan.steps) ~= "table" or #plan.steps == 0 then return false end
    if plan_requires_laboratory(plan) and not laboratory_mode_enabled() then return false end
    if virtual_player ~= nil and virtual_player.running then return false end

    local create_ok, controller = pcall(function()
        local VirtualPlayer = require("modxpector/virtual_player_client")
        return VirtualPlayer.new(inst, {
            max_steps = 200,
            allowed_actions = plan.allowed_actions or {},
            allowed_prefabs = plan.allowed_prefabs or {},
            allowed_recipes = plan.allowed_recipes or {},
            send_rpc = function(kind, request_id, value, count, x, z)
                if kind == "unlock_recipe" then
                    SendModRPCToServer(MOD_RPC[MODNAME].unlock_recipe, request_id, value)
                else
                    local rpc = kind == "spawn_item" and MOD_RPC[MODNAME].spawn_item or MOD_RPC[MODNAME].spawn_entity
                    SendModRPCToServer(rpc, request_id, value, count, x, z)
                end
            end,
            on_finished = function(report)
                if type(DST_GLOBAL.rawset) == "function" then
                    DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_LAST_VIRTUAL_PLAYER_REPORT", report)
                else
                    DST_GLOBAL.MODXPECTOR_LAST_VIRTUAL_PLAYER_REPORT = report
                end
                local result_status = report.outcome == "passed" and "passed"
                    or report.outcome == "failed" and "failed" or "inconclusive"
                record_embedded_suite_result(plan, result_status, {
                    run_id = plan.run_id,
                    outcome = report.outcome,
                    steps_completed = report.steps_completed,
                    steps_verified = report.steps_verified,
                    steps_unverified = report.steps_unverified,
                    assertions_total = report.assertions_total,
                    assertions_passed = report.assertions_passed,
                })
                set_embedded_ai_status("teste_finalizado", tostring(report.outcome or "unknown"))
                print("[ModXpector] VIRTUAL_PLAYER_FINISHED run_id=" .. tostring(plan.run_id or "none")
                    .. " outcome=" .. tostring(report.outcome) .. " steps=" .. tostring(report.steps_completed))
                for _, result in ipairs(report.results or {}) do
                    print("[ModXpector] step=" .. tostring(result.index) .. " status=" .. tostring(result.status)
                        .. " detail=" .. tostring(result.detail))
                end
                if plan.run_id ~= nil and type(SendModRPCToServer) == "function"
                    and MOD_RPC[MODNAME].clear_test_plan ~= nil then
                    SendModRPCToServer(MOD_RPC[MODNAME].clear_test_plan, plan.run_id)
                end
                virtual_player = nil
            end,
        })
    end)
    if not create_ok or type(controller) ~= "table" or type(controller.Start) ~= "function" then
        print("[ModXpector] Virtual Player creation failed: " .. tostring(controller))
        virtual_player = nil
        return false
    end
    virtual_player = controller
    local start_ok, start_result = pcall(function() return virtual_player:Start(plan) end)
    if not start_ok or start_result == false then
        print("[ModXpector] Virtual Player could not start: " .. tostring(start_result))
        virtual_player = nil
        return false
    end
    return true
end

local function run_embedded_ai_suite(suite_id, scenario_id, callback)
    local function finish(success, message, plan)
        if type(callback) == "function" then pcall(callback, success == true, tostring(message or ""), plan) end
    end
    if GetModConfigData("test_mode") ~= true then
        finish(false, "Ative Modo de testes controlados nas opções do ModXpector.")
        return false
    end
    if pending_ai_plan ~= nil then
        finish(false, "Já existe um plano aguardando validação do servidor.")
        return false
    end
    if virtual_player ~= nil and virtual_player.running then
        finish(false, "O Virtual Player já está executando um teste.")
        return false
    end
    local report = DST_GLOBAL.MODXPECTOR_EMBEDDED_AI_REPORT
    local selected = type(report) == "table" and report.selected_suites or {}
    local suite
    for _, entry in ipairs(selected or {}) do
        if type(entry) == "table" and type(entry.suite) == "table" and entry.suite.id == suite_id then
            suite = entry.suite
            break
        end
    end
    if suite == nil then
        finish(false, "A suite não está registrada para um mod ativo e carregado.")
        return false
    end
    local clock = 0
    if type(GetTime) == "function" then
        local clock_ok, value = pcall(GetTime)
        if clock_ok and finite_number(value) then clock = value end
    end
    local sequence = embedded_ai_session ~= nil and #embedded_ai_session.results or 0
    local run_id = "embedded_ai_" .. tostring(math.floor(clock * 1000)) .. "_" .. tostring(sequence + 1)
    local plan, reason = EMBEDDED_AI.BuildVirtualPlayerPlan(suite, scenario_id, run_id)
    if plan == nil then
        finish(false, "Plano rejeitado pelo validador local: " .. tostring(reason))
        return false
    end
    if type(json) ~= "table" or type(json.encode) ~= "function"
        or type(SendModRPCToServer) ~= "function" or MOD_RPC[MODNAME] == nil
        or MOD_RPC[MODNAME].set_test_plan == nil then
        finish(false, "A comunicação segura com o Master não está disponível.")
        return false
    end
    local encode_ok, encoded = pcall(json.encode, plan)
    if not encode_ok or type(encoded) ~= "string" or #encoded > 48 * 1024 then
        finish(false, "Não foi possível serializar o plano de teste.")
        return false
    end
    pending_ai_plan = plan
    set_embedded_ai_status("aguardando_master", "Plano seguro enviado ao Master para validação.")
    local send_ok, send_error = pcall(SendModRPCToServer, MOD_RPC[MODNAME].set_test_plan, run_id, encoded)
    if not send_ok then
        pending_ai_plan = nil
        set_embedded_ai_status("falha_rpc", tostring(send_error))
        finish(false, "Não foi possível enviar o plano ao Master.")
        return false
    end
    if ThePlayer ~= nil and type(ThePlayer.DoTaskInTime) == "function" then
        ThePlayer:DoTaskInTime(25, function()
            if pending_ai_plan == plan then
                pending_ai_plan = nil
                record_embedded_suite_result(plan, "inconclusive", {
                    run_id = run_id,
                    timeout = true,
                    reason = "Master validation response timed out",
                })
                if type(SendModRPCToServer) == "function" and MOD_RPC[MODNAME].clear_test_plan ~= nil then
                    SendModRPCToServer(MOD_RPC[MODNAME].clear_test_plan, run_id)
                end
                set_embedded_ai_status("timeout_master", "O Master não respondeu dentro do prazo; nenhuma execução foi iniciada.")
            end
        end)
    end
    finish(true, "Plano enviado ao Master; aguardando validação antes da execução.", plan)
    return true
end

DST_GLOBAL.MODXPECTOR_RUN_AI_SUITE = run_embedded_ai_suite

if type(AddClientModRPCHandler) == "function" then
    AddClientModRPCHandler(MODNAME, "action_result", function(request_id, success, message)
        if virtual_player ~= nil then virtual_player:OnRPCResult(request_id, success, message) end
    end)
    AddClientModRPCHandler(MODNAME, "plan_ready", function(run_id, success, message)
        if pending_ai_plan == nil or pending_ai_plan.run_id ~= run_id then return end
        local plan = pending_ai_plan
        pending_ai_plan = nil
        if success == true then
            set_embedded_ai_status("plano_aceito", "Master validou a suite; iniciando Virtual Player.")
            local started = start_virtual_player(ThePlayer, plan)
            if not started then
                record_embedded_suite_result(plan, "inconclusive", {
                    run_id = plan.run_id,
                    executor_started = false,
                    reason = "Virtual Player could not start after Master acceptance",
                })
                if type(SendModRPCToServer) == "function" and MOD_RPC[MODNAME].clear_test_plan ~= nil then
                    SendModRPCToServer(MOD_RPC[MODNAME].clear_test_plan, plan.run_id)
                end
                set_embedded_ai_status("executor_indisponivel", "Master aceitou, mas o Virtual Player não conseguiu iniciar.")
            end
        else
            record_embedded_suite_result(plan, "inconclusive", {
                run_id = plan.run_id,
                master_rejected = true,
                reason = tostring(message or "Master rejeitou o plano."),
            })
            set_embedded_ai_status("plano_rejeitado", tostring(message or "Master rejeitou o plano."))
            print("[ModXpector] EMBEDDED_AI_PLAN_REJECTED reason=" .. tostring(message))
        end
    end)
end

local chat_command_listener_installed = false
local chat_command_listener_history = nil
local chat_command_listener = nil
local function chat_system_message(message)
    local history = rawget(DST_GLOBAL, "ChatHistory")
    if history ~= nil and type(history.OnSystemMessage) == "function" then
        pcall(history.OnSystemMessage, history, tostring(message or ""))
    else
        print("[ModXpector Chat] " .. tostring(message or ""))
    end
end

local function handle_modxpector_chat_command(player, message)
    if not CHAT_COMMANDS_OK or player == nil or type(message) ~= "table"
        or message.sender_userid == nil or message.sender_userid ~= player.userid then
        return
    end
    local chat_types = rawget(DST_GLOBAL, "ChatTypes")
    if type(chat_types) == "table" and message.type ~= chat_types.Message then return end
    local parsed = CHAT_COMMANDS.Parse(message.message)
    if parsed == nil then return end

    if parsed.kind == "analyze" then
        chat_system_message("ModXpector: iniciando análise offline dos mods.")
        run_embedded_ai_diagnostics(function(success, result_message)
            chat_system_message("ModXpector: " .. tostring(result_message)
                .. (success and "" or " (não concluído)"))
        end)
    elseif parsed.kind == "status" then
        local state = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_STATUS")
        local status = type(state) == "table" and tostring(state.status or "desconhecido") or "aguardando"
        local detail = type(state) == "table" and tostring(state.detail or "") or ""
        local active = virtual_player ~= nil and virtual_player.running == true
        chat_system_message("ModXpector: IA " .. status .. " | Virtual Player ativo: "
            .. tostring(active) .. (detail ~= "" and " | " .. detail or ""))
    elseif parsed.kind == "list_suites" then
        local report = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_REPORT")
        local suites = type(report) == "table" and report.selected_suites or {}
        if #suites == 0 then
            chat_system_message("ModXpector: nenhuma suite disponível. Execute /mx analisar e verifique os mods ativos.")
        else
            local names = {}
            for _, entry in ipairs(suites) do
                local suite = type(entry) == "table" and entry.suite or nil
                local scenario = type(suite) == "table" and suite.scenarios and suite.scenarios[1] or nil
                if suite ~= nil and scenario ~= nil and #names < 3 then
                    names[#names + 1] = suite.id .. " " .. scenario.id
                end
            end
            chat_system_message("ModXpector suites: " .. table.concat(names, " | ")
                .. ". Use /mx testar <suite_id> <cenario_id>.")
        end
    elseif parsed.kind == "run_suite" then
        run_embedded_ai_suite(parsed.suite_id, parsed.scenario_id, function(success, result_message)
            chat_system_message("ModXpector: " .. tostring(result_message)
                .. (success and "" or " (não iniciado)"))
        end)
    elseif parsed.kind == "stop" then
        local stopped = false
        if virtual_player ~= nil and virtual_player.running == true
            and type(virtual_player.Stop) == "function" then
            virtual_player:Stop("cancelled_by_chat")
            stopped = true
        end
        if pending_ai_plan ~= nil then
            local run_id = pending_ai_plan.run_id
            pending_ai_plan = nil
            if type(SendModRPCToServer) == "function" and MOD_RPC[MODNAME] ~= nil
                and MOD_RPC[MODNAME].clear_test_plan ~= nil then
                pcall(SendModRPCToServer, MOD_RPC[MODNAME].clear_test_plan, run_id)
            end
            stopped = true
        end
        chat_system_message(stopped and "ModXpector: solicitação de parada enviada."
            or "ModXpector: não há teste ativo para parar.")
    elseif parsed.kind == "help" then
        chat_system_message("Comandos: /mx analisar | /mx status | /mx testar | /mx testar <suite_id> <cenario_id> | /mx parar")
    else
        chat_system_message("ModXpector: comando inválido. Use /mx ajuda.")
    end
end

local function install_chat_command_listener(player)
    if player == nil or player ~= rawget(DST_GLOBAL, "ThePlayer") then
        return false
    end
    local history = rawget(DST_GLOBAL, "ChatHistory")
    if history == nil or type(history.AddChatHistoryListener) ~= "function" then
        print("[ModXpector] ChatHistory API indisponível; comandos por chat não foram ativados.")
        return false
    end
    if chat_command_listener_history == history and chat_command_listener ~= nil then
        return true
    end

    if chat_command_listener_history ~= nil and chat_command_listener ~= nil
        and type(chat_command_listener_history.RemoveChatHistoryListener) == "function" then
        pcall(chat_command_listener_history.RemoveChatHistoryListener,
            chat_command_listener_history, chat_command_listener)
    end

    local listener = function(message)
        -- Resolve ThePlayer at dispatch time; reconnects may replace the local entity.
        local current_player = rawget(DST_GLOBAL, "ThePlayer")
        if current_player == nil then return end
        local ok, err = pcall(handle_modxpector_chat_command, current_player, message)
        if not ok then print("[ModXpector] CHAT_COMMAND_HANDLER_FAILED " .. tostring(err)) end
    end
    local ok, err = pcall(history.AddChatHistoryListener, history, listener)
    if not ok then
        chat_command_listener_history = nil
        chat_command_listener = nil
        chat_command_listener_installed = false
        print("[ModXpector] CHAT_COMMAND_LISTENER_FAILED " .. tostring(err))
        return false
    end
    chat_command_listener_history = history
    chat_command_listener = listener
    chat_command_listener_installed = true
    print("[ModXpector] CHAT_COMMAND_LISTENER_READY")
    return true
end

if type(AddPlayerPostInit) == "function" then
    AddPlayerPostInit(function(inst)
        if inst == nil or TheNet == nil then return end
        local dedicated_ok, is_dedicated = pcall(function() return TheNet:IsDedicated() end)
        if not dedicated_ok or is_dedicated then return end
        inst:DoTaskInTime(0, function()
            if inst == ThePlayer then
                install_chat_command_listener(inst)
                inst:DoTaskInTime(8, function() run_embedded_ai_diagnostics() end)
            end
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
        -- Reuse the single startup load. Retrying a failed require can hide the
        -- original module error behind Lua's "loop or previous error loading module".
        local WorldInventory = INVENTORY_OK and WORLD_INVENTORY or nil
        if WorldInventory == nil then
            log("Inventário detalhado indisponível; causa original: "
                .. tostring(INVENTORY_LOAD_ERROR or "módulo não carregado"))
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
