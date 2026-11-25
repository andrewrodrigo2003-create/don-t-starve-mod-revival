local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

local Observer = require("modxpector/step_event_observer")

local function entity(guid)
    local listeners = {}
    local removed = 0
    local result = {
        GUID = guid,
        IsValid = function() return true end,
        ListenForEvent = function(_, event_name, callback)
            listeners[event_name] = listeners[event_name] or {}
            listeners[event_name][#listeners[event_name] + 1] = callback
        end,
        RemoveEventCallback = function(_, event_name, callback)
            removed = removed + 1
            local callbacks = listeners[event_name] or {}
            for index, existing in ipairs(callbacks) do
                if existing == callback then table.remove(callbacks, index); break end
            end
        end,
        Emit = function(self, event_name, data)
            for _, callback in ipairs(listeners[event_name] or {}) do
                callback(self, data)
            end
        end,
        ListenerCount = function(_, event_name)
            return #(listeners[event_name] or {})
        end,
        RemovedCount = function() return removed end,
    }
    return result
end

local classified = entity(900)
local item = entity(901)
local sources = {
    { entity = classified, label = "player_inventory", events = { "itemget", "itemlose" } },
    { entity = item, label = "selected_item", events = { "stacksizechange", "stacksizepreview" } },
}
local now = 12.5
local session = assert(Observer.Start(sources, pcall, function() return now end, 8))
assert(session.active == true and classified:ListenerCount("itemget") == 1)
classified:Emit("itemget", { item = item, slot = 2, ignore_stacksize_anim = true })
classified:Emit("itemlose", { slot = 2 })
item:Emit("stacksizechange", { stacksize = 3 })
item:Emit("stacksizepreview", { stacksize = 2 })
assert(session.event_count == 4, "all supported events should be captured")
local stopped = assert(Observer.Stop(session))
assert(stopped.active == false and stopped.complete == true)
assert(stopped.cleanup_complete == true and stopped.event_count == 4)
assert(stopped.events[1].event == "itemget"
    and stopped.events[2].event == "itemlose"
    and stopped.events[3].event == "stacksizechange"
    and stopped.events[4].event == "stacksizepreview",
    "each listener must retain its own event name")
assert(stopped.evidence == "client_replica_event_shape_only")
assert(stopped.causality == "unproven" and stopped.server_authority == "unverified")
assert(classified:ListenerCount("itemget") == 0 and item:ListenerCount("stacksizechange") == 0)
local removed_before = classified:RemovedCount() + item:RemovedCount()
Observer.Stop(session)
assert(classified:RemovedCount() + item:RemovedCount() == removed_before,
    "stop must be idempotent")

local limited_source = entity(910)
local limited = assert(Observer.Start({
    { entity = limited_source, label = "bounded", events = { "itemget" } },
}, pcall, nil, 1))
limited_source:Emit("itemget", { item = item, slot = 1, ignore_stacksize_anim = true })
limited_source:Emit("itemget", { item = item, slot = 2, ignore_stacksize_anim = true })
local overflow_snapshot = Observer.Snapshot(limited)
assert(overflow_snapshot.overflowed == true and overflow_snapshot.complete == false,
    "event overflow must invalidate the observation")
assert(overflow_snapshot.active == false and overflow_snapshot.cleanup_complete == true)
assert(limited_source:ListenerCount("itemget") == 0,
    "overflow must immediately remove listeners")

local invalid, invalid_reason = Observer.Start({
    { entity = {}, label = "bad", events = { "itemget" } },
}, pcall)
assert(invalid == nil and invalid_reason == "invalid_event_source")

local unsupported, unsupported_reason = Observer.Start({
    { entity = entity(920), label = "bad-event", events = { "onremove" } },
}, pcall)
assert(unsupported == nil and unsupported_reason == "unsupported_event_name")

local registration_entity = entity(930)
registration_entity.ListenForEvent = function(_, event_name)
    if event_name == "itemlose" then error("registration rejected") end
end
local registration_failed, registration_reason = Observer.Start({
    { entity = registration_entity, label = "partial", events = { "itemget", "itemlose" } },
}, pcall)
assert(registration_failed == nil and registration_reason == "event_listener_registration_failed")

local bad_limit, bad_limit_reason = Observer.Start({
    { entity = entity(940), label = "limit", events = { "itemget" } },
}, pcall, nil, 999)
assert(bad_limit == nil and bad_limit_reason == "invalid_event_limit")



local cleanup_failure_entity = entity(950)
cleanup_failure_entity.RemoveEventCallback = function() error("cleanup rejected") end
local cleanup_failure_session = assert(Observer.Start({
    { entity = cleanup_failure_entity, label = "cleanup-failure", events = { "itemget" } },
}, pcall))
local cleanup_failure_snapshot = assert(Observer.Stop(cleanup_failure_session))
assert(cleanup_failure_snapshot.cleanup_complete == false
    and cleanup_failure_snapshot.complete == false,
    "listener cleanup failure must invalidate the observation")



local too_many_sources = {}
for index = 1, 17 do
    too_many_sources[index] = {
        entity = entity(1000 + index),
        label = "source-" .. tostring(index),
        events = { "itemget" },
    }
end
local source_limit, source_limit_reason = Observer.Start(too_many_sources, pcall)
assert(source_limit == nil and source_limit_reason == "too_many_event_sources")

local too_many_listeners = {}
for index = 1, 16 do
    too_many_listeners[index] = {
        entity = entity(1100 + index),
        label = "source-" .. tostring(index),
        events = { "itemget", "itemlose", "stacksizechange", "stacksizepreview" },
    }
end
local listener_limit, listener_limit_reason = Observer.Start(too_many_listeners, pcall)
assert(listener_limit == nil and listener_limit_reason == "too_many_event_listeners")


local no_sources, no_sources_reason = Observer.Start({}, pcall)
assert(no_sources == nil and no_sources_reason == "no_event_sources")

local duplicate_source = entity(960)
local duplicate_subscription, duplicate_subscription_reason = Observer.Start({
    { entity = duplicate_source, label = "duplicate", events = { "itemget", "itemget" } },
}, pcall)
assert(duplicate_subscription == nil
    and duplicate_subscription_reason == "duplicate_event_subscription")

print("ModXpector step event observer tests passed")
