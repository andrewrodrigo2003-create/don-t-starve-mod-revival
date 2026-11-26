-- Step-scoped, passive observation of client replica events.
-- Listener ownership is distinct from event origin; events are evidence, not proof of causality.
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
local MAX_LISTENERS = 48
local MAX_TRACKED_ITEMS = 8

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

local function read_field(protected_call, object, key)
    if object == nil then return false, nil end
    return safe_call(protected_call, function() return object[key] end)
end

local function valid_entity(protected_call, entity)
    if type(entity) ~= "table" or type(entity.IsValid) ~= "function" then return false end
    local ok, valid = safe_call(protected_call, entity.IsValid, entity)
    return ok and valid == true
end

local function cleanup(session)
    session.cleanup_attempts = (session.cleanup_attempts or 0) + 1
    local remaining = {}
    for index = #session.listeners, 1, -1 do
        local listener = session.listeners[index]
        local ok = safe_call(session.pcall, listener.owner.RemoveEventCallback,
            listener.owner, listener.event_name, listener.callback, listener.entity)
        if not ok then
            remaining[#remaining + 1] = listener
        end
    end
    session.listeners = remaining
    session.cleaned = #remaining == 0
    session.cleanup_complete = session.cleaned
    return session.cleaned
end

local function subscription_exists(session, owner, event_source, event_name)
    local owners = session.subscriptions[owner]
    local sources = owners ~= nil and owners[event_source] or nil
    return sources ~= nil and sources[event_name] == true
end

local function register_listener(session, owner, event_source, label, event_name)
    if ALLOWED_EVENTS[event_name] ~= true then
        return false, "unsupported_event_name"
    end
    if not valid_entity(session.pcall, owner) or not valid_entity(session.pcall, event_source)
        or type(owner.ListenForEvent) ~= "function"
        or type(owner.RemoveEventCallback) ~= "function" then
        return false, "invalid_event_source"
    end
    if subscription_exists(session, owner, event_source, event_name) then
        return false, "duplicate_event_subscription"
    end
    if #session.listeners >= MAX_LISTENERS then
        return false, "too_many_event_listeners"
    end

    local listener_owner = owner
    local observed_source = event_source
    local observed_label = label
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

        local callback_ok = safe_call(session.pcall, function()
            local event_entity = (observed_event_name == "stacksizechange"
                or observed_event_name == "stacksizepreview") and observed_source or nil
            if observed_event_name == "itemget" then
                local item_ok, item = read_field(session.pcall, data, "item")
                if item_ok and valid_entity(session.pcall, item) then
                    event_entity = item
                    local guid_ok, guid = read_field(session.pcall, item, "GUID")
                    local item_label = observed_label .. "_item_" ..
                        (guid_ok and tostring(guid) or "unknown")
                    for _, dynamic_event in ipairs({ "stacksizechange", "stacksizepreview" }) do
                        local added, add_reason = register_listener(
                            session, listener_owner, item, item_label, dynamic_event)
                        if not added and add_reason ~= "duplicate_event_subscription" then
                            session.complete = false
                        end
                    end
                end
            end

            local classify_ok, classification, reason = safe_call(session.pcall,
                ItemIdentity.ClassifyReplicaEvent, observed_event_name, data,
                event_entity, session.pcall)
            if not classify_ok then
                classification = "unverified"
                reason = "event_classifier_failed"
                session.complete = false
            end

            local timestamp
            if type(session.get_time) == "function" then
                local time_ok, value = safe_call(session.pcall, session.get_time)
                if time_ok and finite_number(value) then timestamp = value end
            end

            local source_guid_ok, source_guid = read_field(session.pcall, observed_source, "GUID")
            local item_ok, item = read_field(session.pcall, data, "item")
            if not item_ok or item == nil then
                if observed_event_name == "stacksizechange"
                    or observed_event_name == "stacksizepreview" then
                    item = observed_source
                else
                    item = nil
                end
            end
            local item_guid_ok, item_guid = read_field(session.pcall, item, "GUID")
            local item_prefab_ok, item_prefab = read_field(session.pcall, item, "prefab")
            local slot_ok, slot = read_field(session.pcall, data, "slot")
            local stack_ok, stack_size = read_field(session.pcall, data, "stacksize")
            local old_stack_ok, old_stack_size = read_field(session.pcall, data, "oldstacksize")
            local marker_ok, ignore_stacksize_anim = read_field(
                session.pcall, data, "ignore_stacksize_anim")

            session.event_count = session.event_count + 1
            session.events[#session.events + 1] = {
                index = session.event_count,
                source = observed_label,
                event = observed_event_name,
                classification = classification,
                reason = reason,
                timestamp = timestamp,
                source_guid = source_guid_ok and source_guid or nil,
                entity_guid = source_guid_ok and source_guid or nil,
                item_guid = item_guid_ok and finite_number(item_guid) and item_guid or nil,
                item_prefab = item_prefab_ok and type(item_prefab) == "string"
                    and #item_prefab <= 64 and item_prefab or nil,
                slot = slot_ok and type(slot) == "number"
                    and finite_number(slot) and slot >= 1 and slot == math.floor(slot)
                    and slot or nil,
                stack_size = stack_ok and finite_number(stack_size)
                    and stack_size >= 1 and stack_size == math.floor(stack_size)
                    and stack_size or nil,
                old_stack_size = old_stack_ok and finite_number(old_stack_size)
                    and old_stack_size >= 1 and old_stack_size == math.floor(old_stack_size)
                    and old_stack_size or nil,
                ignore_stacksize_anim = marker_ok and type(ignore_stacksize_anim) == "boolean"
                    and ignore_stacksize_anim or nil,
            }
        end)
        if not callback_ok then session.complete = false end
    end

    local listen_ok = safe_call(session.pcall, listener_owner.ListenForEvent,
        listener_owner, observed_event_name, callback, observed_source)
    if not listen_ok then
        return false, "event_listener_registration_failed"
    end

    session.subscriptions[owner] = session.subscriptions[owner] or {}
    session.subscriptions[owner][event_source] = session.subscriptions[owner][event_source] or {}
    session.subscriptions[owner][event_source][event_name] = true
    session.listeners[#session.listeners + 1] = {
        owner = owner,
        entity = event_source,
        event_name = event_name,
        callback = callback,
        label = label,
    }
    return true
end

function M.BuildReplicaSources(player, target, protected_call, tracked_items)
    if type(protected_call) ~= "function"
        or not valid_entity(protected_call, player)
        or not valid_entity(protected_call, target) then
        return nil, "invalid_player_or_target"
    end

    local player_replica_ok, player_replica = read_field(protected_call, player, "replica")
    local inventory_ok, inventory = false, nil
    if player_replica_ok then
        inventory_ok, inventory = read_field(protected_call, player_replica, "inventory")
    end
    if not inventory_ok or type(inventory) ~= "table" then
        return nil, "player_inventory_replica_unavailable"
    end
    local classified_ok, inventory_classified = read_field(protected_call, inventory, "classified")
    if not classified_ok or not valid_entity(protected_call, inventory_classified)
        or type(inventory_classified.IsBusy) ~= "function" then
        return nil, "player_inventory_classified_unavailable"
    end
    local inventory_busy_ok, inventory_busy = safe_call(protected_call,
        inventory_classified.IsBusy, inventory_classified)
    if not inventory_busy_ok or inventory_busy ~= false then
        return nil, "player_inventory_classified_busy_or_unknown"
    end

    local target_replica_ok, target_replica = read_field(protected_call, target, "replica")
    if not target_replica_ok or type(target_replica) ~= "table" then
        return nil, "target_replica_unavailable"
    end
    local container_ok, container = read_field(protected_call, target_replica, "container")
    if not container_ok or type(container) ~= "table" then
        return nil, "target_container_replica_unavailable"
    end
    if type(container.IsBusy) ~= "function" or type(container.IsOpenedBy) ~= "function" then
        return nil, "target_container_state_api_unavailable"
    end
    local target_busy_ok, target_busy = safe_call(protected_call, container.IsBusy, container)
    local target_open_ok, target_open = safe_call(protected_call, container.IsOpenedBy, container, player)
    if not target_busy_ok or target_busy ~= false or not target_open_ok or target_open ~= true then
        return nil, "target_container_busy_closed_or_unknown"
    end
    local container_classified_ok, container_classified = read_field(protected_call, container, "classified")
    if not container_classified_ok or not valid_entity(protected_call, container_classified)
        or type(container_classified.IsBusy) ~= "function" then
        return nil, "target_container_classified_unavailable"
    end
    local classified_busy_ok, classified_busy = safe_call(protected_call,
        container_classified.IsBusy, container_classified)
    if not classified_busy_ok or classified_busy ~= false then
        return nil, "target_container_classified_busy_or_unknown"
    end

    local sources = {
        { owner = player, entity = player, label = "player_inventory", events = { "itemget", "itemlose" } },
        { owner = player, entity = target, label = "target_container", events = { "itemget", "itemlose" } },
    }
    if tracked_items ~= nil then
        if type(tracked_items) ~= "table" or #tracked_items > MAX_TRACKED_ITEMS then
            return nil, "invalid_tracked_item_list"
        end
        for index, item in ipairs(tracked_items) do
            if not valid_entity(protected_call, item) then
                return nil, "invalid_tracked_item"
            end
            sources[#sources + 1] = {
                owner = player,
                entity = item,
                label = "tracked_item_" .. tostring(index),
                events = { "stacksizechange", "stacksizepreview" },
            }
        end
    end
    if #sources > MAX_SOURCES then return nil, "too_many_event_sources" end
    return sources
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
    if #sources == 0 then return nil, "no_event_sources" end
    if #sources > MAX_SOURCES then return nil, "too_many_event_sources" end

    local session = {
        schema = "modxpector/step-event-observer/v1",
        active = true,
        complete = true,
        overflowed = false,
        events = {},
        event_count = 0,
        listeners = {},
        subscriptions = {},
        pcall = protected_call,
        get_time = get_time,
        cleanup_complete = false,
        cleanup_attempts = 0,
        max_events = limit,
    }

    local function fail_start(reason)
        session.active = false
        session.complete = false
        local clean = cleanup(session)
        if clean then return nil, reason end
        return nil, reason, session
    end

    for _, source in ipairs(sources) do
        local owner = type(source) == "table" and (source.owner or source.entity) or nil
        local event_source = type(source) == "table" and source.entity or nil
        if type(source) ~= "table" or not valid_entity(protected_call, owner)
            or not valid_entity(protected_call, event_source)
            or type(source.label) ~= "string" or #source.label == 0 or #source.label > 64
            or type(source.events) ~= "table" or #source.events == 0 or #source.events > 4
            or type(owner.ListenForEvent) ~= "function"
            or type(owner.RemoveEventCallback) ~= "function" then
            return fail_start("invalid_event_source")
        end
        local source_event_names = {}
        for _, event_name in ipairs(source.events) do
            if source_event_names[event_name] then
                return fail_start("duplicate_event_subscription")
            end
            source_event_names[event_name] = true
            if #session.listeners >= MAX_LISTENERS then
                return fail_start("too_many_event_listeners")
            end
            if ALLOWED_EVENTS[event_name] ~= true then
                return fail_start("unsupported_event_name")
            end
            local added, reason = register_listener(
                session, owner, event_source, source.label, event_name)
            if not added then return fail_start(reason) end
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
            source_guid = event.source_guid,
            entity_guid = event.entity_guid,
            item_guid = event.item_guid,
            item_prefab = event.item_prefab,
            slot = event.slot,
            stack_size = event.stack_size,
            old_stack_size = event.old_stack_size,
            ignore_stacksize_anim = event.ignore_stacksize_anim,
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
        cleanup_attempts = session.cleanup_attempts or 0,
        pending_cleanup_count = #session.listeners,
        overflowed = session.overflowed == true,
        event_count = session.event_count,
        events = events,
        evidence = "client_replica_event_shape_only",
        causality = "unproven",
        server_authority = "unverified",
    }
end

return M
