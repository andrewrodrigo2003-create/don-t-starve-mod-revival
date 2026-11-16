-- Clean-room behavioral model of the StateGraph registration/lookup contract.
-- Provenance: public DST script mirror stategraph.lua (build/version must be
-- verified against the user's installed game before treating this as L4).
local StateGraph = {}
StateGraph.__index = StateGraph

local function copy_map(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function copy_list(source)
    local result = {}
    for index, value in ipairs(source or {}) do result[index] = value end
    return result
end

function StateGraph.new(name, vanilla_states, vanilla_handlers)
    assert(type(name) == "string" and name ~= "", "stategraph name required")
    return setmetatable({
        name = name,
        vanilla_states = copy_map(vanilla_states),
        vanilla_handlers = copy_map(vanilla_handlers),
        mod_registrations = {},
        states = nil,
        actionhandlers = nil,
        applied_mod_order = nil,
    }, StateGraph)
end

function StateGraph:RegisterModState(mod_name, state_name, state)
    assert(type(mod_name) == "string" and mod_name ~= "", "mod name required")
    assert(type(state_name) == "string" and state_name ~= "", "state name required")
    assert(type(state) == "table", "state definition required")
    local registration = self.mod_registrations[mod_name] or { states = {}, handlers = {} }
    self.mod_registrations[mod_name] = registration
    registration.states[#registration.states + 1] = {
        name = state_name,
        definition = state,
    }
end

function StateGraph:RegisterModActionHandler(mod_name, action_id, handler)
    assert(type(mod_name) == "string" and mod_name ~= "", "mod name required")
    assert(type(action_id) == "string" and action_id ~= "", "action id required")
    assert(type(handler) == "table", "handler definition required")
    local registration = self.mod_registrations[mod_name] or { states = {}, handlers = {} }
    self.mod_registrations[mod_name] = registration
    registration.handlers[#registration.handlers + 1] = {
        action = action_id,
        definition = handler,
    }
end

-- The caller supplies one possible traversal order for the outer mod map.
-- DST's mirrored constructor iterates that map with pairs(), so cross-mod
-- order is not a stable contract. Per-mod registrations are applied in ipairs order.
function StateGraph:Build(mod_order)
    local states = copy_map(self.vanilla_states)
    local handlers = copy_map(self.vanilla_handlers)
    local applied = {}

    for _, mod_name in ipairs(mod_order or {}) do
        local registration = self.mod_registrations[mod_name]
        if registration ~= nil then
            applied[#applied + 1] = mod_name
            for _, entry in ipairs(registration.handlers) do
                handlers[entry.action] = entry.definition
            end
            for _, entry in ipairs(registration.states) do
                states[entry.name] = entry.definition
            end
        end
    end

    self.states = states
    self.actionhandlers = handlers
    self.applied_mod_order = applied
    return self
end

function StateGraph:ResolveAction(action_id, context)
    assert(self.actionhandlers ~= nil, "StateGraph must be built before lookup")
    local handler = self.actionhandlers[action_id]
    if handler == nil then return nil, "no_handler" end
    if handler.condition ~= nil and not handler.condition(context) then
        return nil, "condition_rejected"
    end
    local destination = handler.destination
    if type(destination) == "function" then
        destination = destination(context)
    end
    if destination == nil then return nil, "no_destination" end
    if self.states[destination] == nil then
        return nil, "missing_state:" .. tostring(destination)
    end
    return destination, "ok"
end

function StateGraph:GetState(name)
    assert(self.states ~= nil, "StateGraph must be built before state lookup")
    return self.states[name]
end

return StateGraph
