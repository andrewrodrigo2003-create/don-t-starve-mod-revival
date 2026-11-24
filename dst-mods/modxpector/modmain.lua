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
local PLAN_OK, TEST_PLAN = pcall(require, "modxpector/test_plan")
if not PLAN_OK or type(TEST_PLAN) ~= "table" then
    TEST_PLAN = { schema = "modxpector/test-plan/v1", enabled = false, allowed_prefabs = {}, allowed_recipes = {}, allowed_actions = {}, steps = {} }
end
local CONFIG_SNAPSHOT_OK, CONFIG_SNAPSHOT = pcall(require, "inspector/config_snapshot")
if not CONFIG_SNAPSHOT_OK or type(CONFIG_SNAPSHOT) ~= "table" or type(CONFIG_SNAPSHOT.Read) ~= "function" then
    CONFIG_SNAPSHOT = { Read = function() return {
        open_key = "KEY_F6", show_debug_info = true, ai_bridge_enabled = false,
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

local SERVER_ACTION_ALLOWLIST = {
    ATTACK = true, CHOP = true, MINE = true, DIG = true, HAMMER = true,
    PICK = true, HARVEST = true, PICKUP = true, TILL = true, REPAIR = true,
    WALKTO = true, EAT = true, USEITEM = true, CASTAOE = true, CASTSPELL = true,
    RUMMAGE = true, DISMOUNT = true, MOUNT = true, TALKTO = true, DEPLOY = true,
    PLANT = true, EQUIP = true, UNEQUIP = true, GIVE = true, DROP = true,
    COOK = true, READ = true, SADDLE = true, FISH = true, CATCH = true,
    LIGHT = true, EXTINGUISH = true, SLEEPIN = true, TURNON = true, TURNOFF = true,
    ACTIVATE = true, OPEN = true, CLOSE = true, STORE = true, TAKE = true,
}
local AI_ACTION_ALLOWLIST = { WALKTO = true }
local ASSERTION_ALLOWLIST = {
    player_health_gte = true, player_hunger_gte = true, player_sanity_gte = true,
    player_has_item = true, player_has_item_count_gte = true, player_equipped = true,
    player_near_target = true, player_knows_recipe = true,
    target_exists = true, target_health_lte = true, target_dead = true, target_has_tag = true,
}
local TARGET_ASSERTION_ALLOWLIST = {
    player_near_target = true, target_exists = true, target_health_lte = true,
    target_dead = true, target_has_tag = true,
}
local SIDE_EFFECT_STEP_ALLOWLIST = {
    action = true, craft = true, craft_at_point = true,
    unlock_recipe = true, spawn_item = true, spawn_entity = true,
}

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
        or assertion.kind == "player_equipped" then
        if not prefab_is_allowed(assertion.prefab, plan) then
            return false, "assertion prefab is not in the plan allowlist"
        end
        if assertion.kind == "player_has_item_count_gte"
            and not integer_in_range(assertion.count, 1, 10000) then
            return false, "inventory assertion count must be an integer from 1 to 10000"
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
local bridge_probe_started = false
local bridge_probe_attempts = 0
local probe_local_ai_bridge

local function set_ai_bridge_status(status, detail)
    local snapshot = { status = tostring(status or "unknown"), detail = tostring(detail or "") }
    if type(DST_GLOBAL.rawset) == "function" then
        DST_GLOBAL.rawset(DST_GLOBAL, "MODXPECTOR_AI_BRIDGE_STATUS", snapshot)
    else
        DST_GLOBAL.MODXPECTOR_AI_BRIDGE_STATUS = snapshot
    end
end

set_ai_bridge_status(GetModConfigData("ai_bridge_enabled") == true and "aguardando_verificacao" or "desativada")

local function schedule_game_poll(inst, delay)
    if inst ~= nil and inst:IsValid() and bridge_poll_enabled and inst == ThePlayer and poll_game_test_plan ~= nil then
        inst:DoTaskInTime(delay or 5, function() poll_game_test_plan(inst) end)
    end
end

local function send_game_report(inst, plan, report, token, port)
    if TheSim == nil or type(TheSim.QueryServer) ~= "function" or type(token) ~= "string" then return end
    local body = {
        run_id = tostring(report.run_id or plan.run_id or ""),
        outcome = tostring(report.outcome or "unknown"),
        failure = report.failure ~= nil and tostring(report.failure) or nil,
        evidence_level = tostring(report.evidence_level or "unknown"),
        player = report.player ~= nil and tostring(report.player) or nil,
        started_at = tonumber(report.started_at),
        finished_at = tonumber(report.finished_at),
        duration_seconds = tonumber(report.duration_seconds),
        steps_completed = tonumber(report.steps_completed) or 0,
        steps_verified = tonumber(report.steps_verified) or 0,
        verification_assertions_passed = tonumber(report.verification_assertions_passed) or 0,
        steps_unverified = tonumber(report.steps_unverified) or 0,
        unverified_step_indices = report.unverified_step_indices or {},
        assertions_total = tonumber(report.assertions_total) or 0,
        assertions_passed = tonumber(report.assertions_passed) or 0,
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
            set_ai_bridge_status("teste_finalizado", tostring(report.outcome or "unknown"))
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
            set_ai_bridge_status("plano_aceito", "Plano recebido do agente local.")
            print("[ModXpector] GAME_TEST_PLAN_ACCEPTED run_id=" .. tostring(run_id))
            local plan = pending_plan
            pending_plan = nil
            start_virtual_player(ThePlayer, plan, bridge_token, bridge_port)
        else
            set_ai_bridge_status("plano_rejeitado", tostring(message))
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
    local token = token_value:match("^([%w_%-]+)%s*$")
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
                bridge_poll_enabled = false
                bridge_probe_started = false
                if probe_local_ai_bridge ~= nil then
                    inst:DoTaskInTime(5, function() probe_local_ai_bridge(inst) end)
                else
                    inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
                end
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
        bridge_poll_enabled = false
        bridge_probe_started = false
        if probe_local_ai_bridge ~= nil then
            inst:DoTaskInTime(5, function() probe_local_ai_bridge(inst) end)
        else
            inst:DoTaskInTime(15, function() poll_game_test_plan(inst) end)
        end
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
    if not INVENTORY_OK or type(WORLD_INVENTORY) ~= "table" or type(WORLD_INVENTORY.Collect) ~= "function" then
        finish(false, {
            error = "world_inventory_module_unavailable",
            detail = tostring(INVENTORY_LOAD_ERROR or "inventory module unavailable"),
        })
        return false
    end
    local collect_ok, inventory = pcall(WORLD_INVENTORY.Collect, DST_GLOBAL)
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
        set_ai_bridge_status("desativada", "Ative IA local nas opções do ModXpector.")
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


local function parse_ai_allowlist_csv(raw, pattern, maximum, action_allowlist)
    if type(raw) ~= "string" then return nil, "lista de permissões inválida" end
    local result, seen = {}, {}
    for token in (raw .. ","):gmatch("(.-),") do
        token = token:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then
            if #token > 64 or not token:match(pattern) then
                return nil, "identificador inválido: " .. token
            end
            if seen[token] then return nil, "identificador duplicado: " .. token end
            if action_allowlist ~= nil and action_allowlist[token] ~= true then
                return nil, "ação não permitida: " .. token
            end
            if #result >= maximum then return nil, "limite de itens excedido" end
            seen[token] = true
            result[#result + 1] = token
        end
    end
    return result
end

local function request_ai_test_plan(goal, prefabs_csv, actions_csv, callback)
    local function finish(success, message, payload)
        if type(callback) == "function" then pcall(callback, success == true, tostring(message or ""), payload) end
    end
    if GetModConfigData("ai_bridge_enabled") ~= true then
        finish(false, "Ative IA local nas opções do ModXpector.")
        return false
    end
    if GetModConfigData("test_mode") ~= true then
        finish(false, "Ative Modo de testes controlados nas opções do ModXpector.")
        return false
    end
    if not bridge_poll_enabled then
        finish(false, "A ponte ainda não confirmou a conexão com o agente local.")
        return false
    end
    if bridge_token == nil then bridge_token = read_bridge_token() end
    if bridge_token == nil then
        finish(false, "bridge_token.txt ausente ou inválido.")
        return false
    end
    if type(goal) ~= "string" then
        finish(false, "Descreva o objetivo do teste.")
        return false
    end
    goal = goal:gsub("^%s+", ""):gsub("%s+$", "")
    if #goal < 5 or #goal > 2000 then
        finish(false, "O objetivo precisa ter entre 5 e 2000 caracteres.")
        return false
    end
    local prefabs, prefab_error = parse_ai_allowlist_csv(prefabs_csv, "^[a-z0-9_%-]+$", 40)
    if prefabs == nil or #prefabs == 0 then
        finish(false, prefab_error or "Informe pelo menos um prefab permitido.")
        return false
    end
    local actions, action_error = parse_ai_allowlist_csv(actions_csv, "^[A-Z0-9_]+$", 40, AI_ACTION_ALLOWLIST)
    if actions == nil or #actions == 0 then
        finish(false, action_error or "Informe pelo menos uma ação permitida.")
        return false
    end
    if TheSim == nil or type(TheSim.QueryServer) ~= "function" then
        finish(false, "TheSim:QueryServer não está disponível.")
        return false
    end
    local payload = {
        goal = goal,
        allowed_prefabs = prefabs,
        allowed_recipes = {},
        allowed_actions = actions,
    }
    local encoded_ok, encoded = pcall(function() return json.encode(payload) end)
    if not encoded_ok or type(encoded) ~= "string" or #encoded > 12 * 1024 then
        finish(false, "Não foi possível preparar o pedido de teste.")
        return false
    end
    local url = "http://127.0.0.1:" .. tostring(bridge_port) .. "/api/dst/plan?token=" .. bridge_token
    local request_ok, request_error = pcall(function()
        TheSim:QueryServer(url, function(body, successful, code)
            if not successful or code ~= 200 or type(body) ~= "string" then
                local detail = "Falha HTTP " .. tostring(code)
                if type(body) == "string" then
                    local decoded_ok, decoded = pcall(function() return json.decode(body) end)
                    if decoded_ok and type(decoded) == "table" and type(decoded.detail) == "string" then
                        detail = decoded.detail
                    end
                end
                set_ai_bridge_status("falha_geracao", detail)
                print("[ModXpector] AI_TEST_PLAN_REQUEST_FAILED code=" .. tostring(code))
                finish(false, detail)
                return
            end
            local decoded_ok, response = pcall(function() return json.decode(body) end)
            if not decoded_ok or type(response) ~= "table" or response.queued ~= true
                or type(response.run_id) ~= "string" then
                set_ai_bridge_status("resposta_invalida", "O agente não confirmou o enfileiramento do plano.")
                finish(false, "Resposta inválida do agente local.")
                return
            end
            set_ai_bridge_status("plano_enfileirado", "Plano " .. response.run_id .. " aguardando o Virtual Player.")
            print("[ModXpector] AI_TEST_PLAN_QUEUED run_id=" .. response.run_id
                .. " steps=" .. tostring(response.steps or "?"))
            finish(true, "Plano gerado e enfileirado. O Virtual Player vai buscá-lo automaticamente.", response)
        end, "POST", encoded, 120)
    end)
    if not request_ok then
        set_ai_bridge_status("falha_requisicao", tostring(request_error))
        finish(false, "Falha ao consultar o agente local: " .. tostring(request_error))
        return false
    end
    set_ai_bridge_status("gerando_plano", "O Ollama está elaborando o plano de teste.")
    return true
end

DST_GLOBAL.MODXPECTOR_REQUEST_AI_TEST = request_ai_test_plan

probe_local_ai_bridge = function(inst)
    if bridge_probe_started or inst == nil or inst ~= ThePlayer then return end
    if GetModConfigData("ai_bridge_enabled") ~= true then
        set_ai_bridge_status("desativada", "Ative IA local nas opções do ModXpector.")
        return
    end
    set_ai_bridge_status("verificando", "Verificando serviço local em 127.0.0.1:" .. tostring(bridge_port))
    if TheSim == nil or type(TheSim.QueryServer) ~= "function" then
        set_ai_bridge_status("api_indisponivel", "TheSim:QueryServer não está disponível no cliente.")
        print("[ModXpector] LOCAL_AI_BRIDGE_UNAVAILABLE reason=queryserver_missing")
        return
    end
    bridge_port = tonumber(GetModConfigData("ai_bridge_port")) or 8765
    if bridge_port < 1024 or bridge_port > 65535 then bridge_port = 8765 end
    bridge_probe_started = true
    bridge_probe_attempts = bridge_probe_attempts + 1
    local function retry_probe()
        set_ai_bridge_status("servico_offline", "O serviço local não respondeu. Nova tentativa automática limitada.")
        bridge_probe_started = false
        if GetModConfigData("ai_bridge_enabled") == true and inst:IsValid() then
            local retry_delay = math.min(60, 5 * (2 ^ math.min(bridge_probe_attempts, 4)))
            inst:DoTaskInTime(retry_delay, function() probe_local_ai_bridge(inst) end)
        end
    end
    bridge_token = read_bridge_token()
    if bridge_token == nil then
        set_ai_bridge_status("token_ausente", "bridge_token.txt não foi encontrado ou não pôde ser lido.")
        print("[ModXpector] LOCAL_AI_BRIDGE_TOKEN_MISSING")
        retry_probe()
        return
    end
    local url = "http://127.0.0.1:" .. tostring(math.floor(bridge_port))
        .. "/api/dst/health?token=" .. bridge_token
    local ok, err = pcall(function()
        TheSim:QueryServer(url, function(body, is_successful, result_code)
            if not is_successful or result_code ~= 200 or type(body) ~= "string" then
                set_ai_bridge_status("servico_offline", "Resposta HTTP " .. tostring(result_code))
                print("[ModXpector] LOCAL_AI_BRIDGE_OFFLINE code=" .. tostring(result_code))
                retry_probe()
                return
            end
            local decoded_ok, payload = pcall(function() return json.decode(body) end)
            if not decoded_ok or type(payload) ~= "table"
                or payload.protocol ~= "modxpector-dst-bridge/v1"
                or payload.bridge ~= "ready" then
                set_ai_bridge_status("resposta_invalida", "O serviço respondeu, mas não reconheceu o protocolo ModXpector.")
                print("[ModXpector] LOCAL_AI_BRIDGE_INVALID_RESPONSE")
                retry_probe()
                return
            end
            local agent_status = type(payload.agent) == "table" and tostring(payload.agent.status or "unknown") or "unknown"
            local agent_message = type(payload.agent) == "table" and tostring(payload.agent.message or "") or ""
            if agent_status ~= "ready" then
                bridge_poll_enabled = false
                bridge_probe_started = false
                set_ai_bridge_status("agente_indisponivel", agent_message ~= "" and agent_message or "Ollama/modelo local indisponível.")
                print("[ModXpector] LOCAL_AI_BRIDGE_AGENT_UNAVAILABLE status=" .. agent_status)
                if inst:IsValid() then
                    inst:DoTaskInTime(30, function() probe_local_ai_bridge(inst) end)
                end
                return
            end
            bridge_probe_attempts = 0
            set_ai_bridge_status("conectada", "Agente local pronto: " .. agent_status .. " | porta " .. tostring(bridge_port))
            print("[ModXpector] LOCAL_AI_BRIDGE_READY port=" .. tostring(bridge_port) .. " agent=" .. agent_status)
            bridge_poll_enabled = true
            send_world_inventory(inst, bridge_token, bridge_port)
            if GetModConfigData("test_mode") == true then
                inst:DoTaskInTime(3, function() poll_game_test_plan(inst) end)
            else
                set_ai_bridge_status("conectada_modo_teste_desativado", "Ative também Modo de testes nas opções do ModXpector.")
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
