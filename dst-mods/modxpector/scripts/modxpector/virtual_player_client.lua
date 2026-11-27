-- Client-side virtual player. Uses the actual PlayerController/BufferedAction
-- pipeline; it never creates a fake network player or bypasses server authority.
-- DST mod environments may hide pcall; use the engine global table.
local DST_GLOBAL = GLOBAL or _G
local pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall
local ItemIdentity = require("modxpector/item_identity")
local STEP_EVENT_OBSERVER_OK, StepEventObserver = pcall(require, "modxpector/step_event_observer")
if not STEP_EVENT_OBSERVER_OK or type(StepEventObserver) ~= "table"
    or type(StepEventObserver.BuildPlayerSources) ~= "function"
    or type(StepEventObserver.Start) ~= "function"
    or type(StepEventObserver.Stop) ~= "function" then
    StepEventObserver = nil
end
local TEST_PLAN_POLICY_OK, TEST_PLAN_POLICY = pcall(require, "modxpector/test_plan_policy")
if not TEST_PLAN_POLICY_OK or type(TEST_PLAN_POLICY) ~= "table"
    or type(TEST_PLAN_POLICY.IsClientActionAllowed) ~= "function" then
    TEST_PLAN_POLICY = {
        IsBlockedAction = function() return true end,
        IsClientActionAllowed = function() return false end,
    }
end
local VirtualPlayer = {}
VirtualPlayer.__index = VirtualPlayer

local SIDE_EFFECT_STEPS = {
    action = true, craft = true, craft_at_point = true,
    unlock_recipe = true, spawn_item = true, spawn_entity = true,
}

local function is_finite_number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function remove_event_listener(owner, event_name, callback, source)
    if owner == nil or type(owner.RemoveEventCallback) ~= "function" then
        return false, false
    end
    local removed = pcall(owner.RemoveEventCallback, owner, event_name, callback, source)
    if not removed then return false, false end
    if type(owner.ListenerExists) == "function" then
        local verify_ok, exists = pcall(owner.ListenerExists, owner, event_name, callback, source)
        if not verify_ok or exists == true then return false, false end
        if exists == false then return true, true end
    end
    -- The runtime accepted the removal call, but does not expose independent listener inspection.
    return true, nil
end

local function safe_get_time()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    return ok and is_finite_number(value) and value or nil
end

local function as_array(value)
    if value == nil then return nil end
    if type(value) == "string" then return { value } end
    return value
end

function VirtualPlayer.new(player, options)
    assert(player ~= nil and player:IsValid(), "a live local player entity is required")
    local self = setmetatable({}, VirtualPlayer)
    self.player = player
    self.options = options or {}
    self.max_steps = math.max(1, math.min(self.options.max_steps or 100, 200))
    self.poll_interval = 0.15
    self.default_timeout = 20
    self.stuck_timeout = math.max(1, math.min(tonumber(self.options.stuck_timeout) or 6, 30))
    local path_replan_attempts = tonumber(self.options.max_path_replan_attempts)
    self.max_path_replan_attempts = path_replan_attempts ~= nil
        and math.max(0, math.min(math.floor(path_replan_attempts), 2)) or 1
    self.queue = {}
    self.index = 0
    self.results = {}
    self.running = false
    self.active = nil
    self.next_request_id = 0
    self.send_rpc = self.options.send_rpc
    self.on_finished = self.options.on_finished
    self.allowed_actions = {}
    self.allowed_prefabs = {}
    self.allowed_recipes = {}
    for _, action_name in ipairs(self.options.allowed_actions or {}) do
        if type(action_name) == "string" then self.allowed_actions[action_name] = true end
    end
    for _, prefab in ipairs(self.options.allowed_prefabs or {}) do
        if type(prefab) == "string" then self.allowed_prefabs[prefab] = true end
    end
    for _, recipe_name in ipairs(self.options.allowed_recipes or {}) do
        if type(recipe_name) == "string" then self.allowed_recipes[recipe_name] = true end
    end
    -- Bind lifecycle listeners only when a run starts; idle controllers must not retain the player.
    return self
end

function VirtualPlayer:_bind_events()
    if self.player_onremove_callback ~= nil
        or self.player == nil or type(self.player.ListenForEvent) ~= "function" then
        return false
    end
    local callback = function()
        self:Stop("player entity removed")
    end
    local owner = self.player
    local ok = pcall(owner.ListenForEvent, owner, "onremove", callback)
    if ok then
        self.player_onremove_callback = callback
        self.player_onremove_owner = owner
        return true
    end
    return false
end

function VirtualPlayer:_cleanup_player_listener()
    local callback = self.player_onremove_callback
    if callback == nil then return true end
    local owner = self.player_onremove_owner or self.player
    local removed, verified = remove_event_listener(owner, "onremove", callback)
    self.player_onremove_cleanup_verified = verified
    self.player_onremove_cleanup_verification = removed
        and (verified == true and "verified" or "unverified") or "pending"
    if removed then
        self.player_onremove_callback = nil
        self.player_onremove_owner = nil
        return true
    end
    return false
end

function VirtualPlayer:ResolveTarget(selector)
    if selector == nil then return nil end
    if type(selector) ~= "table" then error("target selector must be an object") end
    if type(selector.prefab) ~= "string" or not self.allowed_prefabs[selector.prefab] then
        error("target prefab is not in the test plan allowlist")
    end
    assert(self.player.Transform ~= nil and type(self.player.Transform.GetWorldPosition) == "function",
        "player world position API unavailable")
    local x, y, z = self.player.Transform:GetWorldPosition()
    assert(is_finite_number(x) and is_finite_number(z), "player world position is invalid")

    local radius = tonumber(selector.radius) or 12
    if not is_finite_number(radius) then radius = 12 end
    radius = math.max(1, math.min(radius, 40))
    local must = as_array(selector.tags)
    local cant = as_array(selector.notags)
    local oneof = as_array(selector.oneoftags)
    assert(TheSim ~= nil and type(TheSim.FindEntities) == "function", "entity search API unavailable")
    local candidates = TheSim:FindEntities(x, y, z, radius, must, cant, oneof) or {}
    if type(candidates) ~= "table" then return nil end

    local matches = {}
    for order, entity in ipairs(candidates) do
        -- A single stale or partially removed entity must not abort the whole scan.
        local ok, candidate = pcall(function()
            if entity == nil or entity == self.player
                or type(entity.IsValid) ~= "function" or entity:IsValid() ~= true then
                return nil
            end
            if entity.prefab ~= selector.prefab then return nil end
            if selector.tag ~= nil then
                if type(selector.tag) ~= "string" or type(entity.HasTag) ~= "function"
                    or entity:HasTag(selector.tag) ~= true then
                    return nil
                end
            end
            local transform = entity.Transform
            if transform == nil or type(transform.GetWorldPosition) ~= "function" then return nil end
            local ex, _, ez = transform:GetWorldPosition()
            if not is_finite_number(ex) or not is_finite_number(ez) then return nil end
            local dx, dz = ex - x, ez - z
            local distance_sq = dx * dx + dz * dz
            if not is_finite_number(distance_sq) then return nil end
            local guid = entity.GUID
            if type(guid) ~= "number" and type(guid) ~= "string" then guid = nil end
            if type(guid) == "number" and not is_finite_number(guid) then guid = nil end
            return {
                entity = entity,
                distance_sq = distance_sq,
                guid = guid,
                guid_type = type(guid),
                order = order,
            }
        end)
        if ok and candidate ~= nil then matches[#matches + 1] = candidate end
    end

    table.sort(matches, function(a, b)
        if a.distance_sq ~= b.distance_sq then return a.distance_sq < b.distance_sq end
        -- GUID breaks equal-distance ties consistently across entity-list ordering.
        if a.guid ~= nil and b.guid ~= nil then
            if a.guid_type ~= b.guid_type then return a.guid_type < b.guid_type end
            if a.guid ~= b.guid then return a.guid < b.guid end
        elseif a.guid ~= nil then
            return true
        elseif b.guid ~= nil then
            return false
        end
        return a.order < b.order
    end)
    return matches[1] ~= nil and matches[1].entity or nil
end

function VirtualPlayer:_resolve_assertion_target(assertion)
    if assertion.target_step ~= nil then
        local index = tonumber(assertion.target_step)
        if not is_finite_number(index) or index ~= math.floor(index)
            or index < 1 or index >= self.index then
            error("target_step must reference a previous action step")
        end
        local target = self.step_targets ~= nil and self.step_targets[index] or nil
        if target == nil then error("target_step has no captured entity reference") end
        return target
    end
    return self:ResolveTarget(assert(assertion.target, "target selector required"))
end

function VirtualPlayer:BuildAction(step, target_override)
    assert(type(step) == "table", "action step must be an object")
    local action_name = step.action
    assert(type(action_name) == "string" and not TEST_PLAN_POLICY.IsBlockedAction(action_name),
        "inventory transfer action is blocked until exact item identity and container transition are verified")
    assert(TEST_PLAN_POLICY.IsClientActionAllowed(action_name, self.allowed_actions),
        "action is not allowed by the test plan")
    assert(ACTIONS ~= nil and ACTIONS[action_name] ~= nil, "action is not available in this DST build: " .. action_name)
    assert(type(BufferedAction) == "function", "BufferedAction API unavailable")
    local target = target_override ~= nil and target_override or self:ResolveTarget(step.target)
    if step.target_required then assert(target ~= nil, "requested action target was not found") end
    local position
    if step.position ~= nil then
        assert(type(step.position) == "table" and is_finite_number(step.position.x) and is_finite_number(step.position.z), "invalid action position")
        position = Vector3(step.position.x, step.position.y or 0, step.position.z)
    end
    local invobject
    if step.invobject ~= nil then
        assert(self.allowed_prefabs[step.invobject], "action inventory item is not in the test plan prefab allowlist")
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil and type(inventory.FindItem) == "function", "inventory replica unavailable")
        invobject = inventory:FindItem(function(item) return item ~= nil and item.prefab == step.invobject end)
        if invobject == nil and type(inventory.GetEquippedItem) == "function" then
            for _, slot in pairs(EQUIPSLOTS or {}) do
                local equipped = inventory:GetEquippedItem(slot)
                if equipped ~= nil and equipped.prefab == step.invobject then
                    invobject = equipped
                    break
                end
            end
        end
        assert(invobject ~= nil, "requested inventory item not found in carried or equipped items: " .. tostring(step.invobject))
    end
    return BufferedAction(self.player, target, ACTIONS[action_name], invobject, position)
end

function VirtualPlayer:_handle_runtime_error(err, step)
    if not self.running then return false end
    local failed_step = step or (self.active ~= nil and self.active.step) or self.queue[self.index]
    if type(failed_step) ~= "table" then failed_step = { kind = "run" } end
    local detail = "unhandled Virtual Player runtime error: " .. tostring(err)
    self:_record(failed_step, "failed", detail)
    self:_finish(false, "virtual player runtime error at step " .. tostring(self.index) .. ": " .. tostring(err))
    return true
end

function VirtualPlayer:_schedule(delay, fn)
    if not self.running or self.player == nil then return end
    local ok, err = pcall(function()
        if not self.player:IsValid() then
            self:_finish(false, "player entity is no longer valid")
            return
        end
        self.player:DoTaskInTime(math.max(0, delay or 0), function()
            if not self.running then return end
            local callback_ok, callback_error = pcall(fn)
            if not callback_ok then self:_handle_runtime_error(callback_error) end
        end)
    end)
    if not ok then self:_handle_runtime_error(err) end
end

function VirtualPlayer:_record(step, status, detail)
    local timestamp = safe_get_time()
    local target_prefab = type(step.target) == "table" and step.target.prefab or nil
    target_prefab = target_prefab or step.prefab
    self.results[#self.results + 1] = {
        run_id = self.run_id,
        index = self.index,
        kind = step.kind,
        action = step.action,
        target_prefab = target_prefab,
        recipe = step.recipe,
        status = status,
        detail = detail,
        timestamp = timestamp,
        elapsed_seconds = timestamp ~= nil and self.step_started_at ~= nil
            and math.max(0, timestamp - self.step_started_at) or nil,
    }
    if step.kind ~= "run" and (status == "completed" or status == "passed"
        or status == "submitted_unverified" or status == "cleared_unverified") then
        self.steps_completed = (self.steps_completed or 0) + 1
    end
    if SIDE_EFFECT_STEPS[step.kind] == true
        and (status == "completed" or status == "submitted_unverified" or status == "cleared_unverified") then
        self.unverified_steps = self.unverified_steps or {}
        self.unverified_steps[self.index] = { index = self.index, kind = step.kind }
    end
end

function VirtualPlayer:_mark_step_verified(step_references)
    local indices = type(step_references) == "table" and step_references or { step_references }
    local seen = {}
    for _, step_index in ipairs(indices) do
        local index = tonumber(step_index)
        if not is_finite_number(index) or index ~= math.floor(index)
            or index < 1 or index >= self.index then
            error("verifies_step must reference a previous plan step")
        end
        if seen[index] then error("verification references must not contain duplicates") end
        seen[index] = true
        if self.unverified_steps == nil or self.unverified_steps[index] == nil then
            error("verifies_step does not reference an unverified action step")
        end
        local required = self.verification_requirements[index] or 1
        local passed = (self.verification_assertions[index] or 0) + 1
        if passed > required then error("too many postconditions reference the same action step") end
        self.verification_assertions[index] = passed
        if passed >= required then
            self.unverified_steps[index] = nil
            self.steps_verified = (self.steps_verified or 0) + 1
        end
    end
end

function VirtualPlayer:_cancel_active_action()
    local active = self.active
    if active == nil or active.action == nil or self.player == nil
        or type(self.player.GetBufferedAction) ~= "function" then
        return false
    end

    local current_ok, current = pcall(self.player.GetBufferedAction, self.player)
    if not current_ok or current ~= active.action then
        -- Never cancel a newer action started by the player or another system.
        return false
    end

    local locomotor = type(self.player.components) == "table"
        and self.player.components.locomotor or nil
    local entity_action = self.player.bufferedaction
    local locomotor_action = locomotor ~= nil and locomotor.bufferedaction or nil
    if entity_action ~= active.action and locomotor_action ~= active.action then
        return false
    end

    local cancelled = false
    if locomotor ~= nil and locomotor_action == active.action then
        if type(locomotor.Stop) == "function" then
            pcall(locomotor.Stop, locomotor)
        end
        if type(locomotor.Clear) == "function" then
            -- LocoMotor:Clear removes its destination and buffered action.
            local clear_ok = pcall(locomotor.Clear, locomotor)
            cancelled = clear_ok or cancelled
        end
    end

    if self.player.bufferedaction == active.action
        and type(self.player.ClearBufferedAction) == "function" then
        -- EntityScript:ClearBufferedAction clears the entity-side buffered action.
        local clear_ok = pcall(self.player.ClearBufferedAction, self.player)
        cancelled = clear_ok or cancelled
    end

    -- A successful API call is not proof that the action actually stopped.
    -- Confirm that neither EntityScript nor Locomotor still exposes our action.
    local verify_ok, current_after = pcall(self.player.GetBufferedAction, self.player)
    if not verify_ok or current_after == active.action
        or self.player.bufferedaction == active.action
        or (locomotor ~= nil and locomotor.bufferedaction == active.action) then
        return false
    end
    return true
end

function VirtualPlayer:_finish(ok, message)
    if not ok then
        if self.active ~= nil and self.active.action ~= nil then
            local cancel_ok, cancelled = pcall(self._cancel_active_action, self)
            self.active_action_cancellation = cancel_ok and (cancelled and "cancelled" or "not_cancelled")
                or "error"
        else
            self.active_action_cancellation = "not_needed"
        end
    end
    self:_stop_step_event_observer()
    if self.active_step_event_observer ~= nil then self.run_inconclusive = true end
    local target_cleanup_complete = self:_cleanup_target_listeners()
    if not target_cleanup_complete then self.run_inconclusive = true end
    local player_listener_was_registered = self.player_onremove_callback ~= nil
    local player_cleanup_complete = self:_cleanup_player_listener()
    if not player_cleanup_complete or self.player_onremove_callback ~= nil
        or (player_listener_was_registered and self.player_onremove_cleanup_verified ~= true) then
        self.run_inconclusive = true
    end
    if not target_cleanup_complete or self.target_listener_cleanup_verified ~= true then
        self.run_inconclusive = true
    end
    for _, observer_result in pairs(self.step_event_observer_results or {}) do
        if type(observer_result) == "table" and observer_result.cleanup_complete == true
            and observer_result.cleanup_verification ~= "verified" then
            self.run_inconclusive = true
        end
    end
    if not ok then
        local current_step = self.queue[self.index]
        if current_step ~= nil then
            local last = self.results[#self.results]
            local terminal_status = {
                completed = true, passed = true, failed = true, timeout = true, inconclusive = true,
                submitted_unverified = true, cleared_unverified = true,
            }
            if last == nil or last.index ~= self.index or terminal_status[last.status] ~= true then
                local failed_step = type(current_step) == "table" and current_step or { kind = "invalid" }
                self:_record(failed_step, "failed", tostring(message or "step failed"))
            end
        end
    end
    self.running = false
    self.active = nil
    self.finished_at = safe_get_time()
    self.step_started_at = nil
    self.run_failed = not ok
    if self.run_inconclusive then
        self.failure = message or "required listener cleanup or verification remains inconclusive"
    elseif ok then
        self.failure = nil
    else
        self.failure = message
    end
    local final_status = self.run_inconclusive and "inconclusive"
        or (ok and "completed" or "failed")
    self:_record({ kind = "run" }, final_status, message)
    if self.on_finished ~= nil then
        local report_ok, report_or_error = pcall(function() return self:GetReport() end)
        if report_ok then
            local callback_ok, callback_error = pcall(self.on_finished, report_or_error)
            if not callback_ok then self.on_finished_error = tostring(callback_error) end
        else
            self.on_finished_error = "could not build final report: " .. tostring(report_or_error)
        end
    end
end

function VirtualPlayer:Start(plan)
    assert(not self.running, "virtual player is already running")
    assert(type(plan) == "table" and plan.schema == "modxpector/test-plan/v1", "unsupported test plan schema")
    assert(plan.enabled == true, "test plan is disabled")
    assert(type(plan.steps) == "table" and #plan.steps <= self.max_steps, "test plan exceeds step limit")
    for action_index, candidate in ipairs(plan.steps) do
        if type(candidate) == "table" and candidate.kind == "action"
            and candidate.action == "PICKUP" then
            local matching_identity_assertion = false
            for _, postcondition in ipairs(plan.steps) do
                if type(postcondition) == "table" and postcondition.kind == "assert"
                    and type(postcondition.assertion) == "table"
                    and postcondition.assertion.kind == "pickup_target_collected"
                    and postcondition.assertion.target_step == action_index
                    and type(candidate.target) == "table"
                    and postcondition.assertion.prefab == candidate.target.prefab
                    and postcondition.verifies_step == action_index then
                    matching_identity_assertion = true
                    break
                end
            end
            assert(candidate.target_required == true and matching_identity_assertion,
                "PICKUP requires an exact pickup_target_collected postcondition")
        end
    end
    assert(self:_cleanup_player_listener(),
        "previous player onremove listener cleanup is still pending")
    assert(self:_cleanup_target_listeners(),
        "previous target listener cleanup is still pending")
    self.queue = plan.steps
    self.index = 0
    self.run_id = type(plan.run_id) == "string" and plan.run_id or nil
    self.started_at = safe_get_time()
    self.finished_at = nil
    self.step_started_at = nil
    self.active_action_cancellation = nil
    self.results = {}
    self.steps_completed = 0
    self.steps_verified = 0
    self.path_replan_requests = 0
    self.verification_assertions_passed = 0
    self.verification_requirements = {}
    self.verification_assertions = {}
    self:_stop_step_event_observer()
    assert(self.active_step_event_observer == nil,
        "previous step observer still has pending listener cleanup")
    self.step_event_observer_results = {}
    assert(self:_bind_events(), "required player event listeners could not be registered")
    for _, candidate in ipairs(plan.steps) do
        if type(candidate) == "table" and candidate.kind == "assert" then
            if candidate.verifies_step ~= nil then
                local index = tonumber(candidate.verifies_step)
                if is_finite_number(index) and index == math.floor(index) then
                    self.verification_requirements[index] = (self.verification_requirements[index] or 0) + 1
                end
            elseif candidate.verifies_steps ~= nil and type(candidate.verifies_steps) == "table" then
                local seen = {}
                for _, reference in ipairs(candidate.verifies_steps) do
                    local index = tonumber(reference)
                    if is_finite_number(index) and index == math.floor(index) and not seen[index] then
                        seen[index] = true
                        self.verification_requirements[index] = (self.verification_requirements[index] or 0) + 1
                    end
                end
            end
        end
    end
    self.unverified_steps = {}
    self.step_targets = {}
    self.step_inventory_baselines = {}
    self.step_transfer_baselines = {}
    self.step_pickup_baselines = {}
    self.player_onremove_cleanup_verified = nil
    self.player_onremove_cleanup_verification = nil
    self.target_listener_cleanup_verified = nil
    self.target_listener_cleanup_verification = nil
    self.target_death_events = {}
    self.target_death_callbacks = {}
    self.run_inconclusive = false
    self.assertions_total = 0
    self.assertions_passed = 0
    self.running = true
    self:_next()
    return true
end

function VirtualPlayer:_capture_step_target(index, target)
    if target == nil then return end
    self.step_targets[index] = target
    self.target_death_events[index] = false
    if type(target.ListenForEvent) == "function" then
        local callback = function() self.target_death_events[index] = true end
        local ok = pcall(target.ListenForEvent, target, "death", callback)
        if ok then self.target_death_callbacks[index] = callback end
    end
end

function VirtualPlayer:_cleanup_target_listeners()
    local pending = {}
    local all_verified = true
    local verification_available = true
    for index, callback in pairs(self.target_death_callbacks or {}) do
        local target = self.step_targets ~= nil and self.step_targets[index] or nil
        local removed, verified = remove_event_listener(target, "death", callback)
        if not removed then
            removed, verified = remove_event_listener(target, "death", callback)
        end
        if verified == nil then verification_available = false end
        if not removed then
            pending[index] = callback
            all_verified = false
        elseif verified ~= true then
            all_verified = false
        end
    end
    self.target_death_callbacks = pending
    self.target_listener_cleanup_pending = next(pending) ~= nil
    self.target_listener_cleanup_verified = all_verified and verification_available
    self.target_listener_cleanup_verification = self.target_listener_cleanup_pending
        and "pending" or (self.target_listener_cleanup_verified and "verified" or "unverified")
    return not self.target_listener_cleanup_pending
end

function VirtualPlayer:_start_step_event_observer(step, target)
    if step == nil or step.kind ~= "action" or step.action ~= "PICKUP" then
        return false
    end
    if StepEventObserver == nil then
        self.step_event_observer_results[self.index] = {
            complete = false,
            reason = "step_event_observer_unavailable",
        }
        return false
    end

    local sources, source_error = StepEventObserver.BuildPlayerSources(self.player, pcall)
    if sources == nil then
        self.step_event_observer_results[self.index] = {
            complete = false,
            reason = tostring(source_error or "player_inventory_event_sources_unavailable"),
        }
        return false
    end

    local session, start_error, partial_session =
        StepEventObserver.Start(sources, pcall, safe_get_time, 64)
    if session == nil then
        if partial_session ~= nil then
            self.active_step_event_observer = {
                index = self.index,
                session = partial_session,
                target_guid = target ~= nil and target.GUID or nil,
            }
            self:_stop_step_event_observer(self.index)
        else
            self.step_event_observer_results[self.index] = {
                complete = false,
                reason = tostring(start_error or "step_event_observer_start_failed"),
            }
        end
        return false
    end

    local target_guid = target ~= nil and target.GUID or nil
    if not is_finite_number(target_guid) or target_guid < 1
        or target_guid ~= math.floor(target_guid) then
        target_guid = nil
    end
    self.active_step_event_observer = {
        index = self.index,
        session = session,
        target_guid = target_guid,
    }
    return true
end

function VirtualPlayer:_stop_step_event_observer(index)
    local active = self.active_step_event_observer
    if active == nil or (index ~= nil and active.index ~= index) then return nil end
    if StepEventObserver == nil then
        self.step_event_observer_results[active.index] = {
            complete = false,
            cleanup_complete = false,
            reason = "step_event_observer_unavailable_during_cleanup",
        }
        self.run_inconclusive = true
        return self.step_event_observer_results[active.index]
    end

    local snapshot, stop_error = StepEventObserver.Stop(active.session)
    if snapshot ~= nil and snapshot.cleanup_complete ~= true then
        local retry_snapshot = StepEventObserver.Stop(active.session)
        if retry_snapshot ~= nil then snapshot = retry_snapshot end
    end
    if type(snapshot) ~= "table" then
        snapshot = {
            complete = false,
            cleanup_complete = false,
            reason = tostring(stop_error or "step_event_observer_stop_failed"),
            events = {},
        }
    end

    local target_observed = false
    if active.target_guid ~= nil then
        for _, event in ipairs(snapshot.events or {}) do
            if event.event == "itemget"
                and event.classification == "network_shape_candidate"
                and event.item_guid == active.target_guid then
                target_observed = true
                break
            end
        end
    end
    snapshot.target_item_guid = active.target_guid
    snapshot.target_item_observed = target_observed
    snapshot.target_item_observation = target_observed
        and "matching_client_replica_itemget_event"
        or "not_observed_or_not_correlated"
    self.step_event_observer_results[active.index] = snapshot
    if snapshot.cleanup_complete == true then
        self.active_step_event_observer = nil
    end
    return snapshot
end

function VirtualPlayer:_is_valid_target(target)
    if target == nil or type(target.IsValid) ~= "function" then return false end
    local ok, valid = pcall(target.IsValid, target)
    return ok and valid == true
end

function VirtualPlayer:CaptureItemIdentitySnapshot(target)
    -- Diagnostic-only API: it observes client replicas and never submits actions.
    local inventory = self.player ~= nil and self.player.replica ~= nil
        and self.player.replica.inventory or nil
    return ItemIdentity.Capture(inventory, self.player, target, pcall)
end

function VirtualPlayer:_is_target_entity_dead(target, target_step)
    if target == nil then return nil end
    -- A recorded death event is authoritative even after the entity is removed.
    if target_step ~= nil and self.target_death_events ~= nil
        and self.target_death_events[target_step] == true then
        return true
    end
    if not self:_is_valid_target(target) then return nil end
    local health = target.replica ~= nil and target.replica.health or nil
    if health == nil or type(health.GetCurrent) ~= "function" then return nil end
    local current_health = health:GetCurrent()
    if type(current_health) ~= "number" or current_health ~= current_health then return nil end
    return current_health <= 0
end

function VirtualPlayer:_count_player_prefab(inventory, prefab, include_open_containers)
    assert(type(inventory.Has) == "function", "inventory replica Has unavailable")
    local _, raw_total = inventory:Has(prefab, 1, false)
    local total = tonumber(raw_total)
    assert(is_finite_number(total) and total >= 0,
        "inventory replica returned an invalid item count")

    if include_open_containers == true then
        assert(type(inventory.GetOpenContainers) == "function",
            "inventory replica GetOpenContainers unavailable")
        local open_containers = inventory:GetOpenContainers()
        assert(type(open_containers) == "table", "inventory open-container state unavailable")
        local overflow = type(inventory.GetOverflowContainer) == "function"
            and inventory:GetOverflowContainer() or nil
        for container_inst in pairs(open_containers) do
            if container_inst ~= nil and (overflow == nil or container_inst ~= overflow.inst) then
                -- Open-container state can briefly retain an entity during removal.
                -- Never count inventory contents from a stale entity reference.
                assert(type(container_inst.IsValid) == "function",
                    "open container validity API unavailable")
                local valid_ok, valid = pcall(container_inst.IsValid, container_inst)
                if valid_ok and valid == true then
                    local replica = container_inst.replica ~= nil
                        and (container_inst.replica.container or container_inst.replica.inventory) or nil
                    assert(replica ~= nil and replica ~= overflow and type(replica.Has) == "function",
                        "an open container does not expose an item-count replica")
                    local _, raw_found = replica:Has(prefab, 1, false)
                    local found = tonumber(raw_found)
                    assert(is_finite_number(found) and found >= 0,
                        "open container replica returned an invalid item count")
                    total = total + found
                end
            end
        end
    end

    assert(type(inventory.GetEquippedItem) == "function",
        "inventory replica GetEquippedItem unavailable")
    for _, slot in pairs(EQUIPSLOTS or {}) do
        local item = inventory:GetEquippedItem(slot)
        if item ~= nil and item.prefab == prefab then
            local stackable = item.replica ~= nil and item.replica.stackable or nil
            local stack_size = stackable ~= nil and type(stackable.StackSize) == "function"
                and stackable:StackSize() or 1
            stack_size = tonumber(stack_size)
            assert(is_finite_number(stack_size) and stack_size >= 1,
                "equipped item replica returned an invalid stack size")
            total = total + stack_size
        end
    end
    return total
end

function VirtualPlayer:_count_container_prefab(target, prefab)
    assert(self:_is_valid_target(target), "container target is no longer valid")
    local container = target.replica ~= nil and target.replica.container or nil
    assert(container ~= nil and type(container.Has) == "function",
        "target container replica unavailable")
    assert(type(container.IsOpenedBy) == "function",
        "target container open-state API unavailable")
    local open_ok, is_open = pcall(container.IsOpenedBy, container, self.player)
    assert(open_ok and is_open == true,
        "target container must be open to the Virtual Player before counting items")
    local _, raw_count = container:Has(prefab, 1, false)
    local count = tonumber(raw_count)
    assert(is_finite_number(count) and count >= 0,
        "target container replica returned an invalid item count")
    return count
end

function VirtualPlayer:_capture_step_transfer_baseline(step_index, target)
    local player_prefabs, container_prefabs = {}, {}
    for future_index = step_index + 1, #self.queue do
        local candidate = self.queue[future_index]
        if type(candidate) == "table" and candidate.kind == "assert"
            and candidate.assertion ~= nil then
            local assertion = candidate.assertion
            local kind = assertion.kind
            local references = candidate.verifies_steps ~= nil and candidate.verifies_steps or candidate.verifies_step
            local matches = references == step_index
            if type(references) == "table" then
                for _, reference in ipairs(references) do
                    if tonumber(reference) == step_index then matches = true; break end
                end
            end
            if matches and tonumber(assertion.target_step) == step_index
                and type(assertion.prefab) == "string"
                and self.allowed_prefabs[assertion.prefab] then
                if kind == "player_inventory_item_count_increased"
                    or kind == "player_inventory_item_count_decreased" then
                    player_prefabs[assertion.prefab] = true
                elseif kind == "container_item_count_increased" then
                    container_prefabs[assertion.prefab] = true
                end
            end
        end
    end
    if next(player_prefabs) == nil and next(container_prefabs) == nil then return end
    local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
    assert(inventory ~= nil, "inventory replica unavailable for transfer baseline")
    local baseline = { player = {}, container = {} }
    for prefab in pairs(player_prefabs) do
        baseline.player[prefab] = self:_count_player_prefab(inventory, prefab, false)
    end
    for prefab in pairs(container_prefabs) do
        baseline.container[prefab] = self:_count_container_prefab(target, prefab)
    end
    self.step_transfer_baselines = self.step_transfer_baselines or {}
    self.step_transfer_baselines[step_index] = baseline
end

function VirtualPlayer:_capture_step_inventory_baseline(step_index)
    local prefabs = {}
    for future_index = step_index + 1, #self.queue do
        local candidate = self.queue[future_index]
        if type(candidate) == "table" and candidate.kind == "assert"
            and candidate.assertion ~= nil and candidate.assertion.kind == "player_item_count_increased" then
            local assertion = candidate.assertion
            local references = candidate.verifies_steps ~= nil and candidate.verifies_steps or candidate.verifies_step
            local matches = references == step_index
            if type(references) == "table" then
                for _, reference in ipairs(references) do
                    if tonumber(reference) == step_index then matches = true; break end
                end
            end
            if matches and type(assertion.prefab) == "string"
                and self.allowed_prefabs[assertion.prefab] then
                prefabs[assertion.prefab] = true
            end
        end
    end
    if next(prefabs) == nil then return end
    local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
    assert(inventory ~= nil, "inventory replica unavailable for action baseline")
    self.step_inventory_baselines = self.step_inventory_baselines or {}
    self.step_inventory_baselines[step_index] = {}
    for prefab in pairs(prefabs) do
        self.step_inventory_baselines[step_index][prefab] = self:_count_player_prefab(inventory, prefab, true)
    end
end


function VirtualPlayer:_capture_step_pickup_baseline(step_index, target)
    local inventory = self.player ~= nil and self.player.replica ~= nil
        and self.player.replica.inventory or nil
    if inventory == nil or type(ItemIdentity.Capture) ~= "function"
        or type(ItemIdentity.CapturePickupTarget) ~= "function" then
        return false, "pickup identity snapshot APIs are unavailable"
    end
    local before = ItemIdentity.Capture(inventory, self.player, nil, pcall)
    local target_before = ItemIdentity.CapturePickupTarget(target, pcall)
    if type(before) ~= "table" or before.complete ~= true
        or type(target_before) ~= "table" or target_before.complete ~= true then
        return false, "pickup baseline snapshots are incomplete"
    end
    local guid = target ~= nil and target.GUID or nil
    if not is_finite_number(guid) or guid < 1 or guid ~= math.floor(guid)
        or target_before.by_guid == nil or target_before.by_guid[guid] == nil then
        return false, "selected pickup target has no stable GUID identity"
    end
    if before.player.by_guid[guid] ~= nil then
        return false, "selected pickup target already appears in the player inventory baseline"
    end
    self.step_pickup_baselines = self.step_pickup_baselines or {}
    self.step_pickup_baselines[step_index] = {
        before = before,
        target_before = target_before,
        target = target,
        target_guid = guid,
        prefab = target_before.by_guid[guid].prefab,
    }
    return true
end

function VirtualPlayer:_evaluate_assertion(assertion)
    assert(type(assertion) == "table", "assertion must be an object")
    local kind = assertion.kind
    local actual, expected
    if kind == "player_has_item" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        actual = self:_count_player_prefab(inventory, prefab, true) >= 1
        expected = assertion.expected ~= false
    elseif kind == "player_inventory_has_item" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        actual = self:_count_player_prefab(inventory, prefab, false) >= 1
        expected = assertion.expected ~= false
    elseif kind == "player_health_gte" or kind == "player_hunger_gte" or kind == "player_sanity_gte" then
        local replica_name = kind == "player_health_gte" and "health"
            or kind == "player_hunger_gte" and "hunger" or "sanity"
        local replica = self.player.replica ~= nil and self.player.replica[replica_name] or nil
        assert(replica ~= nil and type(replica.GetCurrent) == "function", replica_name .. " replica unavailable")
        actual, expected = replica:GetCurrent(), tonumber(assertion.value)
        assert(expected ~= nil, replica_name .. " assertion value required")
    elseif kind == "player_item_count_increased" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "assertion item prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        local step_index = tonumber(assertion.target_step)
        assert(is_finite_number(step_index) and step_index == math.floor(step_index)
            and step_index >= 1 and step_index < self.index,
            "item-count increase must reference a previous action step")
        local baseline = self.step_inventory_baselines ~= nil
            and self.step_inventory_baselines[step_index] ~= nil
            and self.step_inventory_baselines[step_index][prefab] or nil
        assert(is_finite_number(baseline), "item-count baseline was not captured for the referenced action")
        local count = assertion.count == nil and 1 or tonumber(assertion.count)
        assert(is_finite_number(count) and count == math.floor(count) and count >= 1 and count <= 10000,
            "item-count increase must be an integer between 1 and 10000")
        actual = self:_count_player_prefab(inventory, prefab, true) - baseline >= count
        expected = true

    elseif kind == "pickup_target_collected" then
        local step_index = tonumber(assertion.target_step)
        assert(is_finite_number(step_index) and step_index == math.floor(step_index)
            and step_index >= 1 and step_index < self.index,
            "pickup identity assertion must reference a previous action step")
        local prefab = assert(assertion.prefab, "pickup assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "pickup assertion prefab is not in the test plan allowlist")
        local baseline = self.step_pickup_baselines ~= nil
            and self.step_pickup_baselines[step_index] or nil
        if type(baseline) ~= "table" or baseline.prefab ~= prefab
            or baseline.target == nil or baseline.target_guid == nil then
            return {
                kind = kind, actual = false, expected = true, passed = false,
                inconclusive = true, reason = "exact pickup baseline is unavailable",
            }
        end
        local inventory = self.player ~= nil and self.player.replica ~= nil
            and self.player.replica.inventory or nil
        if inventory == nil then
            return {
                kind = kind, actual = false, expected = true, passed = false,
                inconclusive = true, reason = "player inventory replica is unavailable after pickup",
            }
        end
        local after = ItemIdentity.Capture(inventory, self.player, nil, pcall)
        local result = ItemIdentity.ComparePickup(
            baseline.before, after, baseline.target_before,
            baseline.target, baseline.target_guid, pcall)
        if type(result) ~= "table" or result.outcome ~= "observed_pickup_candidate" then
            return {
                kind = kind, actual = false, expected = true, passed = false,
                inconclusive = true,
                reason = type(result) == "table" and result.reason or "pickup identity comparison failed",
            }
        end
        if result.prefab ~= prefab then
            return {
                kind = kind, actual = false, expected = true, passed = false,
                inconclusive = true, reason = "collected item prefab does not match the asserted target",
            }
        end
        return {
            kind = kind, actual = true, expected = true, passed = true,
            inconclusive = false, evidence = result.evidence,
            causality = result.causality,
            server_authority = result.server_authority,
            guid = result.guid,
        }
    elseif kind == "player_inventory_item_count_increased"
        or kind == "player_inventory_item_count_decreased"
        or kind == "container_item_count_increased" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "transfer assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "transfer assertion prefab is not in the test plan allowlist")
        local step_index = tonumber(assertion.target_step)
        assert(is_finite_number(step_index) and step_index == math.floor(step_index)
            and step_index >= 1 and step_index < self.index,
            "transfer assertion must reference a previous action step")
        local baseline = self.step_transfer_baselines ~= nil
            and self.step_transfer_baselines[step_index] or nil
        assert(type(baseline) == "table", "transfer baseline was not captured for the referenced action")
        local count = assertion.count == nil and 1 or tonumber(assertion.count)
        assert(is_finite_number(count) and count == math.floor(count) and count >= 1 and count <= 10000,
            "transfer assertion count must be an integer between 1 and 10000")
        if kind == "container_item_count_increased" then
            local before = baseline.container ~= nil and baseline.container[prefab] or nil
            assert(is_finite_number(before), "container transfer baseline was not captured")
            local target = self:_resolve_assertion_target(assertion)
            actual = self:_count_container_prefab(target, prefab) - before >= count
        else
            local before = baseline.player ~= nil and baseline.player[prefab] or nil
            assert(is_finite_number(before), "player transfer baseline was not captured")
            local after = self:_count_player_prefab(inventory, prefab, false)
            if kind == "player_inventory_item_count_increased" then
                actual = after - before >= count
            else
                actual = before - after >= count
            end
        end
        expected = true
    elseif kind == "player_has_item_count_gte" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        local count = tonumber(assertion.count)
        assert(is_finite_number(count) and count == math.floor(count) and count >= 1 and count <= 10000,
            "inventory count assertion must be an integer between 1 and 10000")
        actual = self:_count_player_prefab(inventory, prefab, true) >= count
        expected = assertion.expected ~= false
    elseif kind == "container_has_item" then
        local target = self:_resolve_assertion_target(assertion)
        assert(self:_is_valid_target(target), "container assertion target is no longer valid")
        local prefab = assert(assertion.prefab, "assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        local count = assertion.count == nil and 1 or tonumber(assertion.count)
        assert(is_finite_number(count) and count == math.floor(count) and count >= 1 and count <= 10000,
            "container assertion count must be an integer between 1 and 10000")
        local found = self:_count_container_prefab(target, prefab)
        actual = found >= count
        expected = assertion.expected ~= false
    elseif kind == "player_knows_recipe" then
        local recipe_name = assert(assertion.recipe, "assertion recipe required")
        assert(type(recipe_name) == "string" and #recipe_name > 0 and #recipe_name <= 128
            and recipe_name:match("^[%w_%-]+$"), "invalid assertion recipe name")
        assert(self.allowed_recipes[recipe_name], "assertion recipe is not in the test plan allowlist")
        assert(type(GetValidRecipe) == "function", "GetValidRecipe API unavailable")
        local recipe = GetValidRecipe(recipe_name)
        assert(recipe ~= nil, "assertion recipe is not registered: " .. recipe_name)
        local builder = self.player.replica ~= nil and self.player.replica.builder or nil
        assert(builder ~= nil and type(builder.KnowsRecipe) == "function", "player builder replica unavailable")
        actual = builder:KnowsRecipe(recipe)
        expected = assertion.expected ~= false
    elseif kind == "player_equipped" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil and type(inventory.GetEquippedItem) == "function", "inventory replica GetEquippedItem unavailable")
        assert(EQUIPSLOTS ~= nil and EQUIPSLOTS[assertion.slot] ~= nil, "unknown equipment slot")
        local prefab = assert(assertion.prefab, "equipped item prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "equipped item prefab is not in the test plan allowlist")
        local item = inventory:GetEquippedItem(EQUIPSLOTS[assertion.slot])
        actual = item ~= nil and item.prefab == prefab
        expected = assertion.expected ~= false
    elseif kind == "player_near_target" then
        local radius = assertion.radius == nil and 5 or tonumber(assertion.radius)
        assert(is_finite_number(radius) and radius >= 0 and radius <= 40,
            "player_near_target radius must be finite and between 0 and 40")
        local target = self:_resolve_assertion_target(assertion)
        local target_valid = self:_is_valid_target(target)
        actual = nil
        if target_valid then
            actual = false
            assert(self.player.Transform ~= nil and target.Transform ~= nil
                and type(self.player.Transform.GetWorldPosition) == "function"
                and type(target.Transform.GetWorldPosition) == "function",
                "player_near_target transform API unavailable")
            local px, _, pz = self.player.Transform:GetWorldPosition()
            local tx, _, tz = target.Transform:GetWorldPosition()
            if is_finite_number(px) and is_finite_number(pz)
                and is_finite_number(tx) and is_finite_number(tz) then
                local dx, dz = px - tx, pz - tz
                actual = dx * dx + dz * dz <= radius * radius
            else
                actual = nil
            end
        end
        expected = assertion.expected ~= false
    elseif kind == "target_exists" then
        local target = self:_resolve_assertion_target(assertion)
        actual = self:_is_valid_target(target)
        expected = assertion.expected ~= false
    elseif kind == "target_health_lte" then
        local target = self:_resolve_assertion_target(assertion)
        assert(self:_is_valid_target(target), "health assertion target is missing or no longer valid")
        local health = target.replica ~= nil and target.replica.health or nil
        assert(health ~= nil and type(health.GetCurrent) == "function", "target health replica unavailable")
        actual, expected = health:GetCurrent(), tonumber(assertion.value)
        assert(expected ~= nil, "target health assertion value required")
    elseif kind == "target_dead" then
        local target = self:_resolve_assertion_target(assertion)
        actual = self:_is_target_entity_dead(target, assertion.target_step)
        expected = assertion.expected ~= false
    elseif kind == "target_has_tag" then
        local target = self:_resolve_assertion_target(assertion)
        local target_valid = self:_is_valid_target(target)
        assert(type(assertion.tag) == "string" and #assertion.tag > 0 and #assertion.tag <= 64,
            "target tag must be a non-empty string up to 64 characters")
        if target_valid then
            assert(type(target.HasTag) == "function", "target HasTag API unavailable")
            actual = target:HasTag(assertion.tag) == true
        else
            actual = nil
        end
        expected = assertion.expected ~= false
    else
        error("unsupported virtual-player assertion: " .. tostring(kind))
    end
    local inconclusive = (kind == "target_dead" or kind == "player_near_target"
        or kind == "target_has_tag") and actual == nil
    local passed
    if inconclusive then
        passed = false
    elseif kind == "player_health_gte" or kind == "player_hunger_gte" or kind == "player_sanity_gte" then
        passed = actual >= expected
    elseif kind == "target_health_lte" then
        passed = actual <= expected
    else
        passed = actual == expected
    end
    return { kind = kind, actual = actual, expected = expected, passed = passed, inconclusive = inconclusive }
end

function VirtualPlayer:_submit_craft(step)
    assert(type(step.recipe) == "string" and #step.recipe > 0 and #step.recipe <= 128
        and step.recipe:match("^[%w_%-]+$"), "invalid recipe name")
    assert(self.allowed_recipes[step.recipe] == true, "recipe is not in the test plan allowlist")
    assert(type(GetValidRecipe) == "function", "GetValidRecipe API unavailable")
    local recipe = GetValidRecipe(step.recipe)
    assert(recipe ~= nil, "recipe is not registered: " .. tostring(step.recipe))
    local builder = self.player.replica ~= nil and self.player.replica.builder or nil
    assert(builder ~= nil, "player builder replica unavailable")
    assert(builder:KnowsRecipe(recipe), "player does not know recipe: " .. tostring(step.recipe))
    assert(builder:HasIngredients(recipe), "player lacks ingredients for recipe: " .. tostring(step.recipe))
    if step.kind == "craft" then
        assert(recipe.placer == nil, "placer recipes must use craft_at_point")
        assert(type(builder.MakeRecipeFromMenu) == "function", "BuilderReplica:MakeRecipeFromMenu unavailable")
        builder:MakeRecipeFromMenu(recipe, step.skin)
        return "submitted"
    end

    assert(recipe.placer ~= nil, "craft_at_point requires a recipe with a placer")
    assert(type(step.position) == "table" and is_finite_number(step.position.x) and is_finite_number(step.position.z),
           "craft_at_point requires a finite world position")
    assert(type(builder.BufferBuild) == "function" and type(builder.IsBuildBuffered) == "function"
           and type(builder.CanBuildAtPoint) == "function" and type(builder.MakeRecipeAtPoint) == "function",
           "BuilderReplica buffered-placement API unavailable")
    if not builder:IsBuildBuffered(step.recipe) then
        builder:BufferBuild(step.recipe)
    end
    self.active = {
        step = step,
        started = GetTime(),
        timeout = math.max(1, math.min(tonumber(step.timeout) or 10, 30)),
        phase = "buffer",
    }
    self:_record(step, "started", "waiting for DST builder replica to buffer the placer recipe")
    self:_schedule(self.poll_interval, function() self:_poll_craft_buffer() end)
    return "buffering"
end

function VirtualPlayer:_poll_craft_buffer()
    if not self.running or self.active == nil or self.active.phase ~= "buffer" then return end
    local active = self.active
    local step = active.step
    local builder = self.player.replica ~= nil and self.player.replica.builder or nil
    if builder == nil or type(builder.IsBuildBuffered) ~= "function" then
        self:_record(step, "failed", "builder replica became unavailable while buffering the recipe")
        self:_finish(false, "builder replica unavailable")
        return
    end

    if builder:IsBuildBuffered(step.recipe) then
        local recipe = GetValidRecipe(step.recipe)
        local pos = step.position
        local point = Vector3(pos.x, pos.y or 0, pos.z)
        if not builder:CanBuildAtPoint(point, recipe, step.rotation or 0) then
            self:_record(step, "failed", "DST rejected the requested placement position")
            self:_finish(false, "placement position is not deployable")
            return
        end
        if type(builder.MakeRecipeAtPoint) ~= "function" then
            self:_record(step, "failed", "BuilderReplica:MakeRecipeAtPoint unavailable")
            self:_finish(false, "placement API unavailable")
            return
        end
        builder:MakeRecipeAtPoint(recipe, point, step.rotation or 0, step.skin)
        self:_record(step, "submitted_unverified", "buffered placer recipe submitted through BuilderReplica; verify placement with a target_exists assertion")
        self.active = nil
        self:_schedule(0.5, function() self:_next() end)
    elseif GetTime() - active.started >= active.timeout then
        self:_record(step, "failed", "builder replica did not buffer the recipe; inventory may be hidden or ingredients/recipe unavailable")
        self:_finish(false, "craft_at_point buffer timeout")
    else
        self:_schedule(self.poll_interval, function() self:_poll_craft_buffer() end)
    end
end

function VirtualPlayer:_next_impl()
    if not self.running then return end
    self.index = self.index + 1
    self.step_started_at = safe_get_time()
    local step = self.queue[self.index]
    if step == nil then self:_finish(true, "all steps processed"); return end
    if type(step) ~= "table" then self:_finish(false, "invalid step " .. tostring(self.index)); return end

    self:_capture_step_inventory_baseline(self.index)

    if step.kind == "wait" then
        local seconds = tonumber(step.seconds) or 1
        if not is_finite_number(seconds) or seconds < 0 or seconds > 120 then
            self:_finish(false, "invalid wait duration")
            return
        end
        self:_record(step, "started", "waiting")
        self:_schedule(seconds, function() self:_record(step, "completed", "wait elapsed"); self:_next() end)
    elseif step.kind == "action" then
        if step.action == "STORE" then
            self.run_inconclusive = true
            self:_record(step, "inconclusive",
                "prefab deltas cannot prove the exact inventory item was transferred to this container")
            self:_finish(false,
                "STORE is blocked until exact item identity and container transfer are independently verified")
            return
        end
        if step.action == "TAKEITEM" or step.action == "TAKESINGLEITEM" then
            self.run_inconclusive = true
            self:_record(step, "inconclusive",
                "item identity and target-state transition are not yet independently verified")
            self:_finish(false,
                "TAKEITEM/TAKESINGLEITEM are blocked until the exact target item transfer is verifiable")
            return
        end
        local repeat_until_target_dead = step.repeat_until_target_dead == true
        local max_repeats = tonumber(step.max_repeats)
        local repeat_timeout = tonumber(step.repeat_timeout) or 120
        if step.repeat_until_target_dead ~= nil and type(step.repeat_until_target_dead) ~= "boolean" then
            self:_finish(false, "repeat_until_target_dead must be boolean")
            return
        end
        if repeat_until_target_dead then
            if step.action ~= "ATTACK" or step.target_required ~= true
                or not is_finite_number(max_repeats) or max_repeats ~= math.floor(max_repeats)
                or max_repeats < 1 or max_repeats > 20
                or not is_finite_number(repeat_timeout) or repeat_timeout < 1 or repeat_timeout > 600 then
                self:_finish(false, "repeat-until-dead requires ATTACK, a required target, max_repeats 1..20, and repeat_timeout 1..600")
                return
            end
        elseif step.max_repeats ~= nil or step.repeat_timeout ~= nil then
            self:_finish(false, "max_repeats/repeat_timeout require repeat_until_target_dead")
            return
        end
        local ok, action_or_error = pcall(function() return self:BuildAction(step) end)
        if not ok then self:_record(step, "failed", tostring(action_or_error)); self:_finish(false, tostring(action_or_error)); return end
        local target_entity = action_or_error.target
        if target_entity ~= nil then self:_capture_step_target(self.index, target_entity) end
        if step.action == "PICKUP" then
            local pickup_baseline_ok, pickup_baseline_error = self:_capture_step_pickup_baseline(
                self.index, target_entity)
            if not pickup_baseline_ok then
                self.run_inconclusive = true
                self:_record(step, "inconclusive", tostring(pickup_baseline_error))
                self:_finish(false, "PICKUP identity baseline unavailable: " .. tostring(pickup_baseline_error))
                return
            end
        end
        local baseline_ok, baseline_error = pcall(function()
            self:_capture_step_transfer_baseline(self.index, target_entity)
        end)
        if not baseline_ok then
            self:_record(step, "failed", tostring(baseline_error))
            self:_finish(false, "transfer baseline capture failed: " .. tostring(baseline_error))
            return
        end
        if repeat_until_target_dead then
            local alive_ok, target_dead = pcall(function() return self:_is_target_entity_dead(target_entity, self.index) end)
            if not alive_ok then
                self:_finish(false, "attack target health check failed: " .. tostring(target_dead))
                return
            elseif target_dead == nil then
                self.run_inconclusive = true
                self:_record(step, "inconclusive", "attack target state is unavailable; death cannot be confirmed")
                self:_finish(false, "attack target state is unavailable; death cannot be confirmed")
                return
            elseif target_dead == true then
                self:_finish(false, "attack target is already dead")
                return
            end
        end
        local controller = self.player.components ~= nil and self.player.components.playercontroller or nil
        if controller == nil or type(controller.DoAction) ~= "function" then
            self:_finish(false, "PlayerController:DoAction unavailable")
            return
        end
        local action = action_or_error
        if step.action == "PICKUP" then
            local observer_ok, observer_error = pcall(function()
                self:_start_step_event_observer(step, target_entity)
            end)
            if not observer_ok then
                self.step_event_observer_results[self.index] = {
                    complete = false,
                    reason = "observer_start_error: " .. tostring(observer_error),
                }
            end
        end
        controller:DoAction(action)
        self.active = {
            step = step, action = action, started = GetTime(),
            timeout = math.max(1, math.min(tonumber(step.timeout) or self.default_timeout, 120)),
            repeat_count = 0, max_repeats = repeat_until_target_dead and max_repeats or nil,
            repeat_started = repeat_until_target_dead and GetTime() or nil,
            repeat_timeout = repeat_until_target_dead and repeat_timeout or nil,
            target_entity = repeat_until_target_dead and target_entity or nil,
        }
        self:_record(step, "started", repeat_until_target_dead
            and "ATTACK submitted; bounded repetition will stop when target is dead"
            or "BufferedAction submitted to PlayerController")
        self:_schedule(self.poll_interval, function() self:_poll_action() end)
    elseif step.kind == "unlock_recipe" then
        if type(step.recipe) ~= "string" or #step.recipe == 0 or #step.recipe > 128
            or not step.recipe:match("^[%w_%-]+$") then
            self:_finish(false, "invalid recipe name")
            return
        end
        if self.allowed_recipes[step.recipe] ~= true then
            self:_finish(false, "recipe is not in the test plan allowlist")
            return
        end
        if type(self.send_rpc) ~= "function" then self:_finish(false, "server RPC bridge unavailable"); return end
        self.next_request_id = self.next_request_id + 1
        self.active = { step = step, request_id = self.next_request_id, started = GetTime(), timeout = 15 }
        self:_record(step, "started", "requesting server-authoritative recipe unlock")
        self.send_rpc("unlock_recipe", self.active.request_id, step.recipe,
            nil, nil, nil, self.index, self.run_id)
        self:_schedule(self.poll_interval, function() self:_poll_rpc() end)
    elseif step.kind == "craft" or step.kind == "craft_at_point" then
        local ok, result = pcall(function() return self:_submit_craft(step) end)
        if not ok then
            self:_record(step, "failed", tostring(result))
            self:_finish(false, tostring(result))
        elseif result == "buffering" then
            return
        else
            self:_record(step, "submitted_unverified", "BuilderReplica submitted the craft request; verify the result with an assertion step")
            self:_schedule(0.5, function() self:_next() end)
        end
    elseif step.kind == "assert" then
        local ok, result = pcall(function() return self:_evaluate_assertion(step.assertion) end)
        self.assertions_total = (self.assertions_total or 0) + 1
        if ok and result.passed then
            if step.verifies_step ~= nil or step.verifies_steps ~= nil then
                if step.verifies_step ~= nil and step.verifies_steps ~= nil then
                    self:_record(step, "failed", "use verifies_step or verifies_steps, not both")
                    self:_finish(false, "assertion has conflicting verification references")
                    return
                end
                local references = step.verifies_steps ~= nil and step.verifies_steps or step.verifies_step
                local verify_ok, verify_error = pcall(function()
                    self:_mark_step_verified(references)
                end)
                if not verify_ok then
                    self:_record(step, "failed", tostring(verify_error))
                    self:_finish(false, tostring(verify_error))
                    return
                end
                self.verification_assertions_passed = (self.verification_assertions_passed or 0) + 1
            end
            self.assertions_passed = (self.assertions_passed or 0) + 1
            self:_record(step, "passed", "assertion passed: " .. tostring(result.kind))
            self:_next()
        elseif ok and result.inconclusive then
            self.run_inconclusive = true
            local reason = type(result.reason) == "string" and result.reason or "insufficient evidence"
            self:_record(step, "inconclusive", "assertion could not be evaluated: " .. tostring(result.kind) .. ": " .. reason)
            self:_finish(false, "assertion inconclusive: " .. tostring(result.kind) .. ": " .. reason)
            return
        else
            self:_record(step, "failed", ok and ("assertion failed: " .. tostring(result.kind)) or tostring(result))
            self:_finish(false, ok and "assertion failed" or tostring(result))
        end
    elseif step.kind == "spawn_item" or step.kind == "spawn_entity" then
        if type(step.prefab) ~= "string" or #step.prefab == 0 or #step.prefab > 128
            or not step.prefab:match("^[%w_%-]+$") then
            self:_finish(false, "invalid prefab")
            return
        end
        if self.allowed_prefabs[step.prefab] ~= true then
            self:_finish(false, "spawn prefab is not in the test plan allowlist")
            return
        end
        local count = step.count == nil and 1 or tonumber(step.count)
        if not is_finite_number(count) or count ~= math.floor(count) or count < 1 or count > 20 then
            self:_finish(false, "invalid spawn count")
            return
        end
        if type(self.send_rpc) ~= "function" then self:_finish(false, "server RPC bridge unavailable"); return end
        local x, y, z = self.player.Transform:GetWorldPosition()
        if step.position ~= nil then
            if type(step.position) ~= "table" or not is_finite_number(step.position.x)
                or not is_finite_number(step.position.z) or math.abs(step.position.x) > 100000
                or math.abs(step.position.z) > 100000 then
                self:_finish(false, "invalid spawn position")
                return
            end
            x, z = step.position.x, step.position.z
        end
        self.next_request_id = self.next_request_id + 1
        self.active = { step = step, request_id = self.next_request_id, started = GetTime(), timeout = 15 }
        self:_record(step, "started", "requesting server-authoritative spawn")
        self.send_rpc(step.kind, self.active.request_id, step.prefab, count, x, z,
            self.index, self.run_id)
        self:_schedule(self.poll_interval, function() self:_poll_rpc() end)
    else
        self:_finish(false, "unsupported virtual-player step kind: " .. tostring(step.kind))
    end
end


function VirtualPlayer:_next()
    if not self.running then return end
    local ok, err = pcall(function() self:_next_impl() end)
    if not ok then self:_handle_runtime_error(err, self.queue[self.index]) end
end

function VirtualPlayer:_get_player_position()
    local transform = self.player ~= nil and self.player.Transform or nil
    if transform == nil or type(transform.GetWorldPosition) ~= "function" then return nil end
    local ok, x, y, z = pcall(transform.GetWorldPosition, transform)
    if not ok or not is_finite_number(x) or not is_finite_number(z) then return nil end
    return x, z
end

function VirtualPlayer:_request_path_replan(active)
    local locomotor = self.player ~= nil and self.player.components ~= nil
        and self.player.components.locomotor or nil
    if locomotor == nil or locomotor.bufferedaction ~= active.action
        or locomotor.dest == nil or type(locomotor.ResetPath) ~= "function"
        or type(locomotor.FindPath) ~= "function" then
        return false
    end
    if type(locomotor.dest.IsValid) == "function" then
        local valid_ok, valid = pcall(locomotor.dest.IsValid, locomotor.dest)
        if not valid_ok or valid ~= true then return false end
    end
    local reset_ok = pcall(locomotor.ResetPath, locomotor)
    if not reset_ok then return false end
    -- FindPath skips work when the destination tile matches lastdesttile.
    locomotor.lastdesttile = nil
    local find_ok = pcall(locomotor.FindPath, locomotor)
    return find_ok
end

function VirtualPlayer:_poll_action()
    if not self.running or self.active == nil then return end
    local active = self.active
    local current = self.player:GetBufferedAction()
    if current ~= active.action and current ~= nil then
        self:_record(active.step, "failed", "a different BufferedAction replaced the Virtual Player action before it was verified")
        self:_finish(false, "buffered action replaced at step " .. tostring(self.index))
        return
    end
    if current == active.action then
        if active.step.action == "WALKTO" then
            local locomotor = self.player.components ~= nil and self.player.components.locomotor or nil
            if locomotor ~= nil and locomotor.bufferedaction == active.action and locomotor.dest ~= nil then
                local x, z = self:_get_player_position()
                if x ~= nil and z ~= nil then
                    local now = safe_get_time()
                    if active.path_tracking_started ~= true then
                        active.path_tracking_started = true
                        active.last_progress_at = now
                        active.last_position_x = x
                        active.last_position_z = z
                    else
                        local dx = x - active.last_position_x
                        local dz = z - active.last_position_z
                        if dx * dx + dz * dz >= 0.0625 then
                            active.last_progress_at = now
                            active.last_position_x = x
                            active.last_position_z = z
                        elseif now ~= nil and active.last_progress_at ~= nil
                            and now - active.last_progress_at >= self.stuck_timeout then
                            local attempts = active.path_replan_attempts or 0
                            if attempts < self.max_path_replan_attempts
                                and self:_request_path_replan(active) then
                                active.path_replan_attempts = attempts + 1
                                active.last_progress_at = now
                                active.last_position_x = x
                                active.last_position_z = z
                                self.path_replan_requests = (self.path_replan_requests or 0) + 1
                                self:_record(active.step, "replanned",
                                    "movement stalled; requested a fresh native locomotor path search")
                            else
                                self:_record(active.step, "stuck",
                                    "WALKTO made no measurable progress after the bounded path replan")
                                self:_finish(false, "Virtual Player remained stuck during WALKTO")
                                return
                            end
                        end
                    end
                end
            end
        end
        if active.step.repeat_until_target_dead == true
            and GetTime() - (active.repeat_started or active.started) > (active.repeat_timeout or 120) then
            self:_record(active.step, "timeout", "target remained alive or attack action stayed buffered beyond the total repeat time budget")
            self:_finish(false, "attack repeat timeout")
        elseif GetTime() - active.started > active.timeout then
            self:_record(active.step, "timeout", "BufferedAction did not finish before timeout")
            self:_finish(false, "action timeout at step " .. tostring(self.index))
        else
            self:_schedule(self.poll_interval, function() self:_poll_action() end)
        end
        return
    end
    if active.step.action == "PICKUP" then
        local observer_snapshot = self:_stop_step_event_observer(self.index)
        if observer_snapshot ~= nil and observer_snapshot.cleanup_complete ~= true then
            self.run_inconclusive = true
            self:_record(active.step, "inconclusive",
                "step observer cleanup remains pending; later steps were aborted to prevent cross-step event attribution")
            self:_finish(false, "step observer listener cleanup incomplete")
            return
        end
    end
    if active.step.repeat_until_target_dead == true then
        local repeat_count = (active.repeat_count or 0) + 1
        local check_ok, target_dead = pcall(function()
            return self:_is_target_entity_dead(active.target_entity, self.index)
        end)
        if not check_ok then
            self:_record(active.step, "failed", tostring(target_dead))
            self:_finish(false, "could not verify attack target death: " .. tostring(target_dead))
            return
        end
        if target_dead == true then
            self:_record(active.step, "completed", "target defeated after " .. tostring(repeat_count) .. " attack(s)")
            self.active = nil
            self:_next()
        elseif target_dead == nil then
            self.run_inconclusive = true
            self:_record(active.step, "inconclusive", "target entity disappeared without a confirmed death event")
            self:_finish(false, "attack target disappeared without confirmed death")
        elseif GetTime() - (active.repeat_started or active.started) > (active.repeat_timeout or 120) then
            self:_record(active.step, "timeout", "target remained alive beyond the repeat attack time budget")
            self:_finish(false, "attack repeat timeout")
        elseif repeat_count >= (active.max_repeats or 1) then
            self:_record(active.step, "failed", "target still alive after " .. tostring(repeat_count) .. " attack(s)")
            self:_finish(false, "target not defeated within max_repeats")
        else
            self:_record(active.step, "attack_attempt", "target still alive after " .. tostring(repeat_count) .. " attack(s); repeating")
            local step, timeout, max_repeats = active.step, active.timeout, active.max_repeats
            local repeat_started, total_repeat_timeout = active.repeat_started, active.repeat_timeout
            local target_entity = active.target_entity
            self.active = nil
            self:_schedule(self.poll_interval, function()
                if not self.running then return end
                local ok, next_action = pcall(function() return self:BuildAction(step, target_entity) end)
                if not ok then
                    self:_record(step, "failed", tostring(next_action))
                    self:_finish(false, tostring(next_action))
                    return
                end
                local controller = self.player.components ~= nil and self.player.components.playercontroller or nil
                if controller == nil or type(controller.DoAction) ~= "function" then
                    self:_finish(false, "PlayerController:DoAction unavailable during repeated attack")
                    return
                end
                controller:DoAction(next_action)
                self.active = {
                    step = step, action = next_action, started = GetTime(), timeout = timeout,
                    repeat_count = repeat_count, max_repeats = max_repeats,
                    repeat_started = repeat_started, repeat_timeout = total_repeat_timeout,
                    target_entity = target_entity,
                }
                self:_schedule(self.poll_interval, function() self:_poll_action() end)
            end)
        end
        return
    end
    self:_record(active.step, "cleared_unverified", "buffered action cleared; verify the expected world change with an assertion step")
    self.active = nil
    self:_next()
end

function VirtualPlayer:_poll_rpc()
    if not self.running or self.active == nil then return end
    local active = self.active
    if GetTime() - active.started > active.timeout then
        local operation = active.step ~= nil and active.step.kind or "server operation"
        self:_finish(false, tostring(operation) .. " RPC timeout at step " .. tostring(self.index))
    else
        self:_schedule(self.poll_interval, function() self:_poll_rpc() end)
    end
end

function VirtualPlayer:OnRPCResult(request_id, success, message)
    if not self.running or self.active == nil or self.active.request_id ~= request_id then return false end
    local step = self.active.step
    self:_record(step, success and "completed" or "failed", tostring(message or "server response"))
    self.active = nil
    if success then
        self:_schedule(0.35, function() self:_next() end)
    else
        self:_finish(false, tostring(message or "server rejected test operation"))
    end
    return true
end

function VirtualPlayer:Stop(reason)
    if not self.running then return false end
    self:_finish(false, reason or "stopped")
    return true
end

function VirtualPlayer:GetReport()
    local unverified_step_indices = {}
    for index = 1, self.index do
        if self.unverified_steps ~= nil and self.unverified_steps[index] ~= nil then
            unverified_step_indices[#unverified_step_indices + 1] = index
        end
    end
    local assertions_total = self.assertions_total or 0
    local assertions_passed = self.assertions_passed or 0
    local report_time = self.finished_at or safe_get_time()
    local duration_seconds = self.started_at ~= nil and report_time ~= nil
        and math.max(0, report_time - self.started_at) or nil
    local all_assertions_passed = assertions_total > 0 and assertions_passed == assertions_total
    local outcome = "inconclusive"
    if self.run_inconclusive then
        outcome = "inconclusive"
    elseif self.run_failed then
        outcome = "failed"
    elseif all_assertions_passed and #unverified_step_indices == 0 then
        outcome = "passed"
    end
    local player_prefab
    if self.player ~= nil and type(self.player.IsValid) == "function" then
        local player_ok, player_valid = pcall(self.player.IsValid, self.player)
        if player_ok and player_valid == true then player_prefab = self.player.prefab end
    end
    return {
        schema = "modxpector/live-virtual-player/v1",
        evidence_level = "in-game-runner-unvalidated",
        run_id = self.run_id,
        started_at = self.started_at,
        finished_at = self.finished_at,
        duration_seconds = duration_seconds,
        player = player_prefab,
        running = self.running,
        steps_completed = self.steps_completed or 0,
        steps_verified = self.steps_verified or 0,
        verification_assertions_passed = self.verification_assertions_passed or 0,
        steps_unverified = #unverified_step_indices,
        unverified_step_indices = unverified_step_indices,
        assertions_total = assertions_total,
        assertions_passed = assertions_passed,
        outcome = outcome,
        failure = self.failure,
        active_action_cancellation = self.active_action_cancellation,
        path_replan_requests = self.path_replan_requests or 0,
        on_finished_error = self.on_finished_error,
        results = self.results,
        step_event_observer_results = self.step_event_observer_results or {},
        step_event_observer_cleanup_pending = self.active_step_event_observer ~= nil,
        player_onremove_cleanup_pending = self.player_onremove_callback ~= nil,
        player_onremove_cleanup_verified = self.player_onremove_cleanup_verified,
        player_onremove_cleanup_verification = self.player_onremove_cleanup_verification,
        target_listener_cleanup_pending = self.target_listener_cleanup_pending == true,
        target_listener_cleanup_verified = self.target_listener_cleanup_verified,
        target_listener_cleanup_verification = self.target_listener_cleanup_verification,
    }
end

return VirtualPlayer
