-- Bounded, opt-in ingestion of diagnostic events voluntarily reported by other mods.
-- Reported source identity is always treated as unverified; this module never executes payloads.
local M = {}

local MAX_EVENTS = 128
local MAX_EVENTS_PER_SOURCE = 20
local ALLOWED_KINDS = {
    runtime_error = true,
    compatibility_warning = true,
    capability_observed = true,
    test_result = true,
}
local ALLOWED_SEVERITIES = { error = true, warning = true, info = true }

local state = {
    schema = "modxpector/community-diagnostic-events/v1",
    enabled = false,
    events = {},
    source_counts = {},
    dedupe = {},
    dropped = 0,
    next_id = 1,
}

local function clean(value, limit)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%z\\1-\\8\\11\\12\\14-\\31]", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 0 then return nil end
    if #value > limit then value = value:sub(1, limit) end
    return value
end

local function safe_mod_id(value)
    return type(value) == "string" and #value <= 80
        and (value:match("^workshop%-%d+$") ~= nil
            or value:match("^local%-[%w_%-]+$") ~= nil)
end

local function safe_identifier(value, limit)
    if value == nil then return nil end
    return type(value) == "string" and #value <= limit
        and value:match("^[%w_%-]+$") ~= nil
end

local function now()
    if type(state.get_time) ~= "function" then return 0 end
    local ok, value = pcall(state.get_time)
    if ok and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge then
        return value
    end
    return 0
end

function M.Configure(enabled, get_time)
    state = {
        schema = "modxpector/community-diagnostic-events/v1",
        enabled = enabled == true,
        get_time = type(get_time) == "function" and get_time or nil,
        events = {},
        source_counts = {},
        dedupe = {},
        dropped = 0,
        next_id = 1,
    }
    return state.enabled
end

function M.Report(event)
    if state.enabled ~= true then return false, "disabled_by_configuration" end
    if type(event) ~= "table" or event.schema ~= state.schema then
        return false, "invalid_event_schema"
    end
    if not safe_mod_id(event.mod_id) then return false, "invalid_source_mod_id" end
    if not ALLOWED_KINDS[event.kind] then return false, "unsupported_event_kind" end
    if not ALLOWED_SEVERITIES[event.severity] then return false, "unsupported_event_severity" end

    local message = clean(event.message, 500)
    if message == nil then return false, "invalid_event_message" end
    local stack = event.stack == nil and nil or clean(event.stack, 2000)
    if event.stack ~= nil and stack == nil then return false, "invalid_event_stack" end
    if event.prefab ~= nil and not safe_identifier(event.prefab, 80) then
        return false, "invalid_event_prefab"
    end
    if event.component ~= nil and not safe_identifier(event.component, 40) then
        return false, "invalid_event_component"
    end

    local key = table.concat({
        event.mod_id, event.kind, event.severity, message,
        event.prefab or "", event.component or "", stack or "",
    }, "|")
    local existing_id = state.dedupe[key]
    if existing_id ~= nil then
        for _, existing in ipairs(state.events) do
            if existing.id == existing_id then
                existing.repeat_count = existing.repeat_count + 1
                existing.last_seen = now()
                return true, existing.id, "deduplicated"
            end
        end
    end

    local source_count = state.source_counts[event.mod_id] or 0
    if source_count >= MAX_EVENTS_PER_SOURCE then
        state.dropped = state.dropped + 1
        return false, "source_rate_limit"
    end
    if #state.events >= MAX_EVENTS then
        state.dropped = state.dropped + 1
        return false, "event_buffer_full"
    end

    local timestamp = now()
    local record = {
        id = state.next_id,
        mod_id = event.mod_id,
        source_verified = false,
        kind = event.kind,
        severity = event.severity,
        message = message,
        stack = stack,
        prefab = event.prefab,
        component = event.component,
        first_seen = timestamp,
        last_seen = timestamp,
        repeat_count = 1,
    }
    state.next_id = state.next_id + 1
    state.source_counts[event.mod_id] = source_count + 1
    state.events[#state.events + 1] = record
    state.dedupe[key] = record.id
    return true, record.id, "recorded"
end

function M.Snapshot()
    local events = {}
    for i, event in ipairs(state.events) do
        if i > MAX_EVENTS then break end
        events[#events + 1] = {
            id = event.id,
            mod_id = event.mod_id,
            source_verified = false,
            kind = event.kind,
            severity = event.severity,
            message = clean(event.message, 500),
            stack = event.stack ~= nil and clean(event.stack, 2000) or nil,
            prefab = event.prefab,
            component = event.component,
            first_seen = event.first_seen,
            last_seen = event.last_seen,
            repeat_count = event.repeat_count,
        }
    end
    return {
        schema = state.schema,
        enabled = state.enabled == true,
        available = state.enabled == true,
        event_count = #events,
        dropped = state.dropped,
        max_events = MAX_EVENTS,
        max_events_per_source = MAX_EVENTS_PER_SOURCE,
        events = events,
    }
end

return M
