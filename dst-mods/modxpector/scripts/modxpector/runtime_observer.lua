-- Opt-in, read-only observation of selected DST component post-initializers.
-- This module never wraps/replaces component methods and keeps a bounded event buffer.
local M = {}

local MAX_EVENTS = 256
local COMPONENT_ALLOWLIST = {
    "health", "hunger", "sanity", "inventory", "container", "builder",
    "combat", "workable", "pickable", "harvestable", "growable", "follower",
}

local function clean(value, limit)
    if type(value) ~= "string" then return "unknown" end
    value = value:gsub("[%z\1-\8\11\12\14-\31]", " ")
    limit = limit or 80
    if #value > limit then value = value:sub(1, limit) end
    return value
end

local function store_state(globals, state)
    if type(globals.rawset) == "function" then
        globals.rawset(globals, "MODXPECTOR_RUNTIME_COMPONENTS", state)
    else
        globals.MODXPECTOR_RUNTIME_COMPONENTS = state
    end
end

function M.GetAllowlist()
    local result = {}
    for i, name in ipairs(COMPONENT_ALLOWLIST) do result[i] = name end
    return result
end

function M.Register(add_component_post_init, globals, enabled, protected_call, get_time)
    globals = type(globals) == "table" and globals or {}
    protected_call = type(protected_call) == "function" and protected_call or pcall
    local state = {
        schema = "modxpector/runtime-component-observations/v1",
        enabled = enabled == true,
        available = false,
        registered = false,
        hooks_registered = 0,
        hook_failures = 0,
        callback_errors = 0,
        dropped = 0,
        max_events = MAX_EVENTS,
        counts = {},
        events = {},
    }

    if enabled ~= true then
        state.reason = "disabled_by_configuration"
        store_state(globals, state)
        return false, state
    end
    if type(add_component_post_init) ~= "function" then
        state.reason = "component_post_init_api_unavailable"
        store_state(globals, state)
        return false, state
    end

    local existing = globals.MODXPECTOR_RUNTIME_COMPONENTS
    if type(existing) == "table" and existing.schema == state.schema
        and existing.enabled == true and existing.registered == true then
        return existing.available == true, existing
    end

    state.registered = true
    for _, component_name in ipairs(COMPONENT_ALLOWLIST) do
        local callback = function(component)
            local ok = protected_call(function()
                if type(component) ~= "table" then return end
                local inst = component.inst
                local prefab = "unknown"
                if inst ~= nil then prefab = clean(inst.prefab, 80) end
                local timestamp = 0
                if type(get_time) == "function" then
                    local time_ok, value = protected_call(get_time)
                    if time_ok and type(value) == "number"
                        and value == value and value ~= math.huge and value ~= -math.huge then
                        timestamp = value
                    end
                end

                state.counts[component_name] = (state.counts[component_name] or 0) + 1
                if #state.events < MAX_EVENTS then
                    state.events[#state.events + 1] = {
                        component = component_name,
                        prefab = prefab,
                        time = timestamp,
                    }
                else
                    state.dropped = state.dropped + 1
                end
            end)
            if not ok then state.callback_errors = state.callback_errors + 1 end
        end

        local ok = protected_call(add_component_post_init, component_name, callback)
        if ok then
            state.hooks_registered = state.hooks_registered + 1
        else
            state.hook_failures = state.hook_failures + 1
        end
    end

    state.available = state.hooks_registered > 0
    if not state.available then state.reason = "no_component_hooks_registered" end
    store_state(globals, state)
    return state.available, state
end

function M.Snapshot(globals)
    globals = type(globals) == "table" and globals or {}
    local state = globals.MODXPECTOR_RUNTIME_COMPONENTS
    if type(state) ~= "table" or state.schema ~= "modxpector/runtime-component-observations/v1" then
        return {
            schema = "modxpector/runtime-component-observations/v1",
            enabled = false,
            available = false,
            registered = false,
            hooks_registered = 0,
            hook_failures = 0,
            callback_errors = 0,
            dropped = 0,
            max_events = MAX_EVENTS,
            components = {},
            events = {},
            reason = "not_initialized",
        }
    end

    local components = {}
    for name, count in pairs(type(state.counts) == "table" and state.counts or {}) do
        if type(name) == "string" and type(count) == "number" then
            components[#components + 1] = { name = name, count = count }
        end
    end
    table.sort(components, function(a, b) return a.name < b.name end)

    local events = {}
    for i, event in ipairs(type(state.events) == "table" and state.events or {}) do
        if i > MAX_EVENTS then break end
        if type(event) == "table" then
            events[#events + 1] = {
                component = clean(event.component, 40),
                prefab = clean(event.prefab, 80),
                time = type(event.time) == "number" and event.time or 0,
            }
        end
    end

    return {
        schema = state.schema,
        enabled = state.enabled == true,
        available = state.available == true,
        registered = state.registered == true,
        hooks_registered = tonumber(state.hooks_registered) or 0,
        hook_failures = tonumber(state.hook_failures) or 0,
        callback_errors = tonumber(state.callback_errors) or 0,
        dropped = tonumber(state.dropped) or 0,
        max_events = MAX_EVENTS,
        components = components,
        events = events,
        reason = state.reason,
    }
end

return M
