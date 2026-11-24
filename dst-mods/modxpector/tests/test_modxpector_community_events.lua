local root = os.getenv("DST_RUNTIME_ROOT") or "."
local path = root .. "/dst-mods/modxpector/scripts/modxpector/community_events.lua"
local function fresh() return assert(loadfile(path))() end
local Events = fresh()
local ok, reason = Events.Report({})
assert(ok == false and reason == "disabled_by_configuration",
    "community event ingestion must be disabled until explicitly enabled")

local now = 12
Events.Configure(true, function() return now end)
local valid = {
    schema = "modxpector/community-diagnostic-events/v1",
    mod_id = "workshop-12345",
    kind = "runtime_error",
    severity = "error",
    message = "attempt to index a nil value",
    stack = "scripts/foo.lua:12",
    prefab = "skeletonservant",
    component = "combat",
}
local accepted, id, status = Events.Report(valid)
assert(accepted and id == 1 and status == "recorded")
local snapshot = Events.Snapshot()
assert(snapshot.enabled and snapshot.available and snapshot.event_count == 1)
assert(snapshot.events[1].source_verified == false,
    "community source identity must never be promoted to verified")
assert(snapshot.events[1].message == valid.message and snapshot.events[1].stack == valid.stack)
assert(snapshot.events[1].first_seen == 12 and snapshot.events[1].repeat_count == 1)

now = 18
local repeated, repeated_id, repeated_status = Events.Report(valid)
assert(repeated and repeated_id == id and repeated_status == "deduplicated")
snapshot = Events.Snapshot()
assert(snapshot.event_count == 1 and snapshot.events[1].repeat_count == 2
    and snapshot.events[1].last_seen == 18,
    "identical reports must be deduplicated and counted")

local secret_event = {
    schema = "modxpector/community-diagnostic-events/v1",
    mod_id = "workshop-12345",
    kind = "runtime_error",
    severity = "error",
    message = "Token=secret123 Authorization: Bearer bearer-secret",
    stack = "Authorization: Bearer stack-secret",
}
assert(Events.Report(secret_event) == true)
snapshot = Events.Snapshot()
assert(not snapshot.events[2].message:find("secret123", 1, true)
    and not snapshot.events[2].message:find("bearer-secret", 1, true)
    and not snapshot.events[2].stack:find("stack-secret", 1, true),
    "diagnostic event text must redact common credential patterns")

local invalid_cases = {
    { schema = "wrong", mod_id = "workshop-1", kind = "runtime_error", severity = "error", message = "x" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "not-an-id", kind = "runtime_error", severity = "error", message = "x" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "workshop-1", kind = "execute_code", severity = "error", message = "x" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "workshop-1", kind = "runtime_error", severity = "critical", message = "x" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "workshop-1", kind = "runtime_error", severity = "error", message = "" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "workshop-1", kind = "runtime_error", severity = "error", message = "x", prefab = "../bad" },
    { schema = "modxpector/community-diagnostic-events/v1", mod_id = "workshop-1", kind = "runtime_error", severity = "error", message = "x", component = "bad/name" },
}
for _, event in ipairs(invalid_cases) do
    local accepted_invalid = Events.Report(event)
    assert(accepted_invalid == false, "invalid community event must be rejected")
end

local rate = fresh()
rate.Configure(true)
for i = 1, 20 do
    local accepted_rate = rate.Report({
        schema = "modxpector/community-diagnostic-events/v1",
        mod_id = "workshop-555",
        kind = "capability_observed",
        severity = "info",
        message = "capability_" .. tostring(i),
    })
    assert(accepted_rate == true)
end
local rate_ok, rate_reason = rate.Report({
    schema = "modxpector/community-diagnostic-events/v1",
    mod_id = "workshop-555",
    kind = "capability_observed",
    severity = "info",
    message = "capability_21",
})
assert(rate_ok == false and rate_reason == "source_rate_limit")
assert(rate.Snapshot().dropped == 1)

local bounded = fresh()
bounded.Configure(true)
for source = 1, 7 do
    for item = 1, 20 do
        local accepted_event = bounded.Report({
            schema = "modxpector/community-diagnostic-events/v1",
            mod_id = "workshop-" .. tostring(1000 + source),
            kind = "test_result",
            severity = "info",
            message = "result_" .. tostring(item),
        })
        if source == 7 and item > 8 then
            assert(accepted_event == false, "global event buffer must reject events after its cap")
        else
            assert(accepted_event == true)
        end
    end
end
local bounded_snapshot = bounded.Snapshot()
assert(bounded_snapshot.event_count == 128 and bounded_snapshot.dropped == 12)
bounded_snapshot.events[1].message = "tampered"
assert(bounded.Snapshot().events[1].message == "result_1",
    "event snapshots must not expose mutable internal storage")

print("MODXPECTOR_COMMUNITY_EVENTS_V1_OK")
