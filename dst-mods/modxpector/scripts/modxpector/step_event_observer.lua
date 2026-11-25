-- Step-scoped, passive observation of client replica events.
-- This module never submits actions and never treats event shape as proof of causality.
local ItemIdentity = require("modxpector/item_identity")
local M = {}

local ALLOWED_EVENTS = {
    itemget = true,
    itemlose = true,
    stacksizechange = true,
    stacksizepreview = true,
}
local DEFAULT_MAX_EVENTS = 64
local HARD_MAX_EVENTS = 256
local MAX_SOURCES = 16
local MAX_LISTENERS = 64

local function safe_call(protected_call, fn, ...)
    if type(protected_call) ~= "function" or type(fn) ~= "function" then
        return false, nil
    end
    return protected_call(fn, ...)
end

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function cleanup(session)
    if session.cleaned then return true end
    session.cleaned = true
    local clean = true
    for index = #session.listeners, 1, -1 do
        local listener = session.listeners[index]
        local ok = safe_call(session.pcall, listener.entity.RemoveEventCallback,
            listener.entity, listener.event_name, listener.callback)
        if not ok then clean = false end
    end
    session.listeners = {}
    session.cleanup_complete = clean
    return clean
end

function M.Start(sources, protected_call, get_time, max_events)
    if type(sources) ~= "table" or type(protected_call) ~= "function" then
        return nil, "invalid_observer_arguments"
    end
    local limit = tonumber(max_events) or DEFAULT_MAX_EVENTS
    if not finite_number(limit) or limit ~= math.floor(limit)
        or limit < 1 or limit > HARD_MAX_EVENTS then
        return nil, "invalid_event_limit"
    end

    if #sources > MAX_SOURCES then return nil, "too_many_event_sources" end

    local session = {
        schema = "modxpector/step-event-observer/v1",
        active = true,
        complete = true,
        overflowed = false,
        events = {},
        event_count = 0,
        listeners = {},
        pcall = protected_call,
        cleanup_complete = false,
        max_events = limit,
    }

    for _, source in ipairs(sources) do
        if type(source) ~= "table" or source.entity == nil
            or type(source.label) ~= "string" or type(source.events) ~= "table"
            or type(source.entity.ListenForEvent) ~= "function"
            or type(source.entity.RemoveEventCallback) ~= "function" then
            cleanup(session)
            return nil, "invalid_event_source"
        end
        for _, event_name in ipairs(source.events) do
            if #session.listeners >= MAX_LISTENERS then
                cleanup(session)
                return nil, "too_many_event_listeners"
            end
            if ALLOWED_EVENTS[event_name] ~= true then
                cleanup(session)
                return nil, "unsupported_event_name"
            end
            local event_source = source
            local observed_event_name = event_name
            local callback = function(inst, data)
                if not session.active then return end
                if session.event_count >= session.max_events then
                    session.overflowed = true
                    session.complete = false
                    session.active = false
                    cleanup(session)
                    return
                end
                if data == nil and type(inst) == "table" then
                    data = inst
                    inst = event_source.entity
                end
                local event_entity = nil
                if observed_event_name == "stacksizechange" or observed_event_name == "stacksizepreview" then
                    event_entity = event_source.entity
                end
                local classify_ok, classification, reason = safe_call(protected_call,
                    ItemIdentity.ClassifyReplicaEvent, observed_event_name, data, event_entity, protected_call)
                if not classify_ok then
                    classification = "unverified"
                    reason = "event_classifier_failed"
                    session.complete = false
                end
                local timestamp
                if type(get_time) == "function" then
                    local time_ok, value = safe_call(protected_call, get_time)
                    if time_ok and finite_number(value) then timestamp = value end
                end
                session.event_count = session.event_count + 1
                session.events[#session.events + 1] = {
                    index = session.event_count,
                    source = event_source.label,
                    event = observed_event_name,
                    classification = classification,
                    reason = reason,
                    timestamp = timestamp,
                    entity_guid = type(inst) == "table" and inst.GUID or nil,
                }
            end
            local listen_ok = safe_call(protected_call, event_source.entity.ListenForEvent,
                event_source.entity, observed_event_name, callback)
            if not listen_ok then
                cleanup(session)
                return nil, "event_listener_registration_failed"
            end
            session.listeners[#session.listeners + 1] = {
                entity = event_source.entity,
                event_name = observed_event_name,
                callback = callback,
            }
        end
    end
    return session
end

function M.Stop(session)
    if type(session) ~= "table" or session.schema ~= "modxpector/step-event-observer/v1" then
        return nil, "invalid_observer_session"
    end
    session.active = false
    local clean = cleanup(session)
    return M.Snapshot(session, clean)
end

function M.Snapshot(session, cleanup_result)
    if type(session) ~= "table" or session.schema ~= "modxpector/step-event-observer/v1" then
        return nil, "invalid_observer_session"
    end
    local events = {}
    for index, event in ipairs(session.events) do
        events[index] = {
            index = event.index,
            source = event.source,
            event = event.event,
            classification = event.classification,
            reason = event.reason,
            timestamp = event.timestamp,
            entity_guid = event.entity_guid,
        }
    end
    local cleanup_complete = cleanup_result
    if cleanup_complete == nil then cleanup_complete = session.cleanup_complete end
    return {
        schema = session.schema,
        active = session.active == true,
        complete = session.complete == true and cleanup_complete == true
            and session.overflowed ~= true,
        cleanup_complete = cleanup_complete == true,
        overflowed = session.overflowed == true,
        event_count = session.event_count,
        events = events,
        evidence = "client_replica_event_shape_only",
        causality = "unproven",
        server_authority = "unverified",
    }
end

return M
