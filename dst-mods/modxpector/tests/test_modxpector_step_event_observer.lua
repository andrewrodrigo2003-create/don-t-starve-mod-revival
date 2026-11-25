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
for index = 1, 13 do
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


local malformed_entity, malformed_entity_reason = Observer.Start({
    { entity = 42, label = "malformed-entity", events = { "itemget" } },
}, pcall)
assert(malformed_entity == nil and malformed_entity_reason == "invalid_event_source")



local player_classified = entity(970)
player_classified.IsBusy = function() return false end
local target_classified = entity(971)
target_classified.IsBusy = function() return false end
local source_player = entity(972)
source_player.replica = { inventory = { classified = player_classified } }
local source_target = entity(973)
local target_container_replica = {
    IsBusy = function() return false end,
    IsOpenedBy = function(_, opener) return opener == source_player end,
    classified = target_classified,
}
source_target.replica = { container = target_container_replica }
local replica_sources = assert(Observer.BuildReplicaSources(source_player, source_target, pcall))
assert(#replica_sources == 2
    and replica_sources[1].entity == player_classified
    and replica_sources[2].entity == target_classified,
    "source resolver must use the player's and target's classified replicas")
assert(replica_sources[1].label == "player_inventory"
    and replica_sources[2].label == "target_container")

player_classified.IsBusy = function() return true end
local busy_sources, busy_reason = Observer.BuildReplicaSources(source_player, source_target, pcall)
assert(busy_sources == nil and busy_reason == "player_inventory_classified_busy_or_unknown")
player_classified.IsBusy = function() return false end
target_container_replica.IsBusy = function() return true end
local busy_target_sources, busy_target_reason =
    Observer.BuildReplicaSources(source_player, source_target, pcall)
assert(busy_target_sources == nil
    and busy_target_reason == "target_container_busy_closed_or_unknown")
target_container_replica.IsBusy = function() return false end
target_container_replica.IsOpenedBy = function() return false end
local closed_target_sources, closed_target_reason =
    Observer.BuildReplicaSources(source_player, source_target, pcall)
assert(closed_target_sources == nil
    and closed_target_reason == "target_container_busy_closed_or_unknown")
local invalid_player = entity(974)
invalid_player.IsValid = function() return false end
local invalid_sources, invalid_sources_reason =
    Observer.BuildReplicaSources(invalid_player, source_target, pcall)
assert(invalid_sources == nil and invalid_sources_reason == "invalid_player_or_target")


local stale_event_source = entity(965)
stale_event_source.IsValid = function() return false end
stale_event_source.ListenForEvent = function() end
stale_event_source.RemoveEventCallback = function() end
local stale_source_session, stale_source_reason = Observer.Start({
    { entity = stale_event_source, label = "stale", events = { "itemget" } },
}, pcall)
assert(stale_source_session == nil and stale_source_reason == "invalid_event_source")

print("ModXpector step event observer tests passed")
