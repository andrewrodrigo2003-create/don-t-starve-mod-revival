-- Client-side virtual player. Uses the actual PlayerController/BufferedAction
-- pipeline; it never creates a fake network player or bypasses server authority.
-- DST mod environments may hide pcall; use the engine global table.
local DST_GLOBAL = GLOBAL or _G
local pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall
local VirtualPlayer = {}
VirtualPlayer.__index = VirtualPlayer

local ACTION_ALLOWLIST = {
    ATTACK = true, CHOP = true, MINE = true, DIG = true, HAMMER = true,
    PICK = true, HARVEST = true, PICKUP = true, TILL = true, REPAIR = true,
    WALKTO = true, EAT = true, USEITEM = true, CASTAOE = true, CASTSPELL = true,
    RUMMAGE = true, DISMOUNT = true, MOUNT = true, TALKTO = true, DEPLOY = true,
    PLANT = true, EQUIP = true, UNEQUIP = true, GIVE = true, DROP = true,
    COOK = true, READ = true, SADDLE = true, FISH = true, CATCH = true,
    LIGHT = true, EXTINGUISH = true, SLEEPIN = true, TURNON = true, TURNOFF = true,
    ACTIVATE = true, OPEN = true, CLOSE = true, STORE = true, TAKE = true,
}

local SIDE_EFFECT_STEPS = {
    action = true, craft = true, craft_at_point = true,
    unlock_recipe = true, spawn_item = true, spawn_entity = true,
}

local function is_finite_number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
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
    self:_bind_events()
    return self
end

function VirtualPlayer:_bind_events()
    if self.player.ListenForEvent == nil then return end
    self.player:ListenForEvent("onremove", function()
        self:Stop("player entity removed")
    end)
end

function VirtualPlayer:ResolveTarget(selector)
    if selector == nil then return nil end
    if type(selector) ~= "table" then error("target selector must be an object") end
    if type(selector.prefab) ~= "string" or not self.allowed_prefabs[selector.prefab] then
        error("target prefab is not in the test plan allowlist")
    end
    local x, y, z = self.player.Transform:GetWorldPosition()
    local radius = math.max(1, math.min(tonumber(selector.radius) or 12, 40))
    local must = as_array(selector.tags)
    local cant = as_array(selector.notags)
    local oneof = as_array(selector.oneoftags)
    local candidates = TheSim:FindEntities(x, y, z, radius, must, cant, oneof) or {}
    local matches = {}
    for _, entity in ipairs(candidates) do
        if entity ~= nil and entity:IsValid() and entity ~= self.player then
            local prefab_ok = selector.prefab == nil or entity.prefab == selector.prefab
            local tag_ok = selector.tag == nil or entity:HasTag(selector.tag)
            if prefab_ok and tag_ok then
                local ex, ey, ez = entity.Transform:GetWorldPosition()
                local dx, dz = ex - x, ez - z
                matches[#matches + 1] = { entity = entity, distance_sq = dx * dx + dz * dz }
            end
        end
    end
    table.sort(matches, function(a, b) return a.distance_sq < b.distance_sq end)
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
    assert(type(action_name) == "string" and (ACTION_ALLOWLIST[action_name] or self.allowed_actions[action_name]), "action is not allowed")
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

function VirtualPlayer:_finish(ok, message)
    self:_cleanup_target_listeners()
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
    if ok then
        self.failure = nil
    else
        self.failure = message
    end
    self:_record({ kind = "run" }, ok and "completed" or "failed", message)
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
    self.queue = plan.steps
    self.index = 0
    self.run_id = type(plan.run_id) == "string" and plan.run_id or nil
    self.started_at = safe_get_time()
    self.finished_at = nil
    self.step_started_at = nil
    self.results = {}
    self.steps_completed = 0
    self.steps_verified = 0
    self.verification_assertions_passed = 0
    self.verification_requirements = {}
    self.verification_assertions = {}
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
    for index, callback in pairs(self.target_death_callbacks or {}) do
        local target = self.step_targets ~= nil and self.step_targets[index] or nil
        if target ~= nil and type(target.RemoveEventCallback) == "function" then
            pcall(target.RemoveEventCallback, target, "death", callback)
        end
    end
    self.target_death_callbacks = {}
end

function VirtualPlayer:_is_target_entity_dead(target, target_step)
    if target == nil then return nil end
    if target_step ~= nil and self.target_death_events ~= nil
        and self.target_death_events[target_step] == true then
        return true
    end
    if type(target.IsValid) == "function" then
        local ok, valid = pcall(target.IsValid, target)
        if not ok then error("target validity check failed: " .. tostring(valid)) end
        if valid ~= true then return nil end
    end
    local health = target.replica ~= nil and target.replica.health or nil
    if health == nil or type(health.GetCurrent) ~= "function" then return nil end
    local current_health = health:GetCurrent()
    if type(current_health) ~= "number" or current_health ~= current_health then return nil end
    return current_health <= 0
end

function VirtualPlayer:_count_player_prefab(inventory, prefab)
    assert(type(inventory.Has) == "function", "inventory replica Has unavailable")
    local _, total = inventory:Has(prefab, 1, false)
    total = tonumber(total) or 0

    assert(type(inventory.GetOpenContainers) == "function",
        "inventory replica GetOpenContainers unavailable")
    local open_containers = inventory:GetOpenContainers()
    assert(type(open_containers) == "table", "inventory open-container state unavailable")
    local overflow = type(inventory.GetOverflowContainer) == "function"
        and inventory:GetOverflowContainer() or nil
    for container_inst in pairs(open_containers) do
        if container_inst ~= nil and (overflow == nil or container_inst ~= overflow.inst) then
            local replica = container_inst.replica ~= nil
                and (container_inst.replica.container or container_inst.replica.inventory) or nil
            assert(replica ~= nil and replica ~= overflow and type(replica.Has) == "function",
                "an open container does not expose an item-count replica")
            local _, found = replica:Has(prefab, 1, false)
            total = total + (tonumber(found) or 0)
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
            total = total + math.max(1, tonumber(stack_size) or 1)
        end
    end
    return total
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
        actual = self:_count_player_prefab(inventory, prefab) >= 1
        expected = assertion.expected ~= false
    elseif kind == "player_health_gte" or kind == "player_hunger_gte" or kind == "player_sanity_gte" then
        local replica_name = kind == "player_health_gte" and "health"
            or kind == "player_hunger_gte" and "hunger" or "sanity"
        local replica = self.player.replica ~= nil and self.player.replica[replica_name] or nil
        assert(replica ~= nil and type(replica.GetCurrent) == "function", replica_name .. " replica unavailable")
        actual, expected = replica:GetCurrent(), tonumber(assertion.value)
        assert(expected ~= nil, replica_name .. " assertion value required")
    elseif kind == "player_has_item_count_gte" then
        local inventory = self.player.replica ~= nil and self.player.replica.inventory or nil
        assert(inventory ~= nil, "inventory replica unavailable")
        local prefab = assert(assertion.prefab, "assertion prefab required")
        assert(type(prefab) == "string" and self.allowed_prefabs[prefab],
            "assertion item prefab is not in the test plan allowlist")
        local count = tonumber(assertion.count)
        assert(is_finite_number(count) and count == math.floor(count) and count >= 1 and count <= 10000,
            "inventory count assertion must be an integer between 1 and 10000")
        actual = self:_count_player_prefab(inventory, prefab) >= count
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
        local target = self:_resolve_assertion_target(assertion)
        local target_valid = target ~= nil
        if target_valid and type(target.IsValid) == "function" then
            local valid_ok, valid = pcall(target.IsValid, target)
            target_valid = valid_ok and valid == true
        end
        actual = false
        if target_valid and self.player.Transform ~= nil and target.Transform ~= nil
            and type(self.player.Transform.GetWorldPosition) == "function"
            and type(target.Transform.GetWorldPosition) == "function" then
            local px, _, pz = self.player.Transform:GetWorldPosition()
            local tx, _, tz = target.Transform:GetWorldPosition()
            local dx, dz = px - tx, pz - tz
            local radius = assertion.radius or 5
            actual = dx * dx + dz * dz <= radius * radius
        end
        expected = assertion.expected ~= false
    elseif kind == "target_exists" then
        local target = self:_resolve_assertion_target(assertion)
        actual = target ~= nil
        if actual and type(target.IsValid) == "function" then
            local valid_ok, valid = pcall(target.IsValid, target)
            actual = valid_ok and valid == true
        end
        expected = assertion.expected ~= false
    elseif kind == "target_health_lte" then
        local target = self:_resolve_assertion_target(assertion)
        assert(target ~= nil, "health assertion target not found")
        if type(target.IsValid) == "function" then
            local valid_ok, valid = pcall(target.IsValid, target)
            assert(valid_ok and valid == true, "health assertion target is no longer valid")
        end
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
        local target_valid = target ~= nil
        if target_valid and type(target.IsValid) == "function" then
            local valid_ok, valid = pcall(target.IsValid, target)
            target_valid = valid_ok and valid == true
        end
        actual = target_valid and target:HasTag(assert(assertion.tag, "tag required")) or false
        expected = assertion.expected ~= false
    else
        error("unsupported virtual-player assertion: " .. tostring(kind))
    end
    local inconclusive = kind == "target_dead" and actual == nil
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

    if step.kind == "wait" then
        local seconds = tonumber(step.seconds) or 1
        if not is_finite_number(seconds) or seconds < 0 or seconds > 120 then
            self:_finish(false, "invalid wait duration")
            return
        end
        self:_record(step, "started", "waiting")
        self:_schedule(seconds, function() self:_record(step, "completed", "wait elapsed"); self:_next() end)
    elseif step.kind == "action" then
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
        self.send_rpc("unlock_recipe", self.active.request_id, step.recipe)
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
            self:_record(step, "inconclusive", "assertion could not be evaluated: " .. tostring(result.kind))
            self:_finish(false, "assertion inconclusive: " .. tostring(result.kind))
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
        self.send_rpc(step.kind, self.active.request_id, step.prefab, count, x, z)
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
        on_finished_error = self.on_finished_error,
        results = self.results,
    }
end

return VirtualPlayer
