local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"))
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

local Observer = require("modxpector/step_event_observer")

local function entity(guid, prefab)
    local result = {
        GUID = guid,
        prefab = prefab,
        listeners = {},
        removed = 0,
        IsValid = function(self) return self.valid ~= false end,
        ListenForEvent = function(self, event_name, callback, source)
            source = source or self
            source.listeners = source.listeners or {}
            source.listeners[event_name] = source.listeners[event_name] or {}
            table.insert(source.listeners[event_name], callback)
        end,
        RemoveEventCallback = function(self, event_name, callback, source)
            self.removed = self.removed + 1
            source = source or self
            local callbacks = source.listeners ~= nil and source.listeners[event_name] or nil
            if callbacks ~= nil then
                for index, existing in ipairs(callbacks) do
                    if existing == callback then
                        table.remove(callbacks, index)
                        break
                    end
                end
                if #callbacks == 0 then source.listeners[event_name] = nil end
            end
        end,
        Emit = function(self, event_name, data)
            local callbacks = self.listeners[event_name] or {}
            local dispatch = {}
            for index, callback in ipairs(callbacks) do dispatch[index] = callback end
            for _, callback in ipairs(dispatch) do callback(self, data) end
        end,
        ListenerCount = function(self, event_name)
            return #(self.listeners[event_name] or {})
        end,
        RemovedCount = function(self) return self.removed end,
    }
    return result
end

local player = entity(900, "wilson")
local item = entity(901, "cutgrass")
local sources = {
    { owner = player, entity = player, label = "player_inventory", events = { "itemget", "itemlose" } },
    { owner = player, entity = item, label = "tracked_item", events = { "stacksizechange", "stacksizepreview" } },
}
local now = 12.5
local session = assert(Observer.Start(sources, pcall, function() return now end, 8))
assert(session.active == true and player:ListenerCount("itemget") == 1)
assert(item:ListenerCount("stacksizechange") == 1)

player:Emit("itemget", {
    item = item, slot = 2, ignore_stacksize_anim = true,
})
player:Emit("itemlose", { slot = 2 })
item:Emit("stacksizechange", { stacksize = 3 })
item:Emit("stacksizepreview", { stacksize = 2 })
assert(session.event_count == 4, "all supported events should be captured")

local stopped = assert(Observer.Stop(session))
assert(stopped.active == false and stopped.complete == true)
assert(stopped.cleanup_complete == true and stopped.pending_cleanup_count == 0)
assert(stopped.event_count == 4)
assert(stopped.events[1].event == "itemget"
    and stopped.events[2].event == "itemlose"
    and stopped.events[3].event == "stacksizechange"
    and stopped.events[4].event == "stacksizepreview",
    "each listener must retain its own event name")
assert(stopped.events[1].classification == "network_shape_candidate")
assert(stopped.events[1].item_guid == 901 and stopped.events[1].item_prefab == "cutgrass")
assert(stopped.events[1].slot == 2 and stopped.events[1].ignore_stacksize_anim == true)
assert(stopped.events[2].slot == 2 and stopped.events[2].item_guid == nil)
assert(stopped.events[3].item_guid == 901 and stopped.events[3].stack_size == 3)
assert(stopped.events[4].classification == "preview_or_unverified")
assert(stopped.evidence == "client_replica_event_shape_only")
assert(stopped.causality == "unproven" and stopped.server_authority == "unverified")
assert(player:ListenerCount("itemget") == 0 and item:ListenerCount("stacksizechange") == 0)
local removed_before = player:RemovedCount()
Observer.Stop(session)
assert(player:RemovedCount() == removed_before, "stop must not remove listeners twice")

-- Itemget from the player dynamically subscribes to the newly observed item's stack events.
local dynamic_player = entity(910, "wilson")
local dynamic_item = entity(911, "twigs")
local dynamic_session = assert(Observer.Start({
    { owner = dynamic_player, entity = dynamic_player, label = "player", events = { "itemget" } },
}, pcall))
dynamic_player:Emit("itemget", {
    item = dynamic_item, slot = 1, ignore_stacksize_anim = true,
})
assert(dynamic_item:ListenerCount("stacksizechange") == 1)
dynamic_item:Emit("stacksizechange", { stacksize = 4 })
assert(dynamic_session.event_count == 2)
local dynamic_snapshot = assert(Observer.Stop(dynamic_session))
assert(dynamic_snapshot.events[2].item_guid == 911
    and dynamic_snapshot.events[2].stack_size == 4)
assert(dynamic_item:ListenerCount("stacksizechange") == 0)

-- The event listener owner can differ from the entity that emits the event.
local listener_owner = entity(920, "wilson")
local event_source = entity(921, "chest")
local separate_owner_session = assert(Observer.Start({
    { owner = listener_owner, entity = event_source, label = "container", events = { "itemget" } },
}, pcall))
event_source:Emit("itemget", {
    item = item, slot = 1, ignore_stacksize_anim = true,
})
assert(separate_owner_session.event_count == 1)
assert(listener_owner:ListenerCount("itemget") == 0)
assert(event_source:ListenerCount("itemget") == 1)
local separate_snapshot = assert(Observer.Stop(separate_owner_session))
assert(separate_snapshot.cleanup_complete == true)
assert(event_source:ListenerCount("itemget") == 0)

local limited_source = entity(930, "wilson")
local limited = assert(Observer.Start({
    { owner = limited_source, entity = limited_source, label = "bounded", events = { "itemget" } },
}, pcall, nil, 1))
limited_source:Emit("itemget", nil)
limited_source:Emit("itemget", nil)
local overflow_snapshot = Observer.Snapshot(limited)
assert(overflow_snapshot.overflowed == true and overflow_snapshot.complete == false)
assert(overflow_snapshot.active == false and overflow_snapshot.cleanup_complete == true)
assert(limited_source:ListenerCount("itemget") == 0)

local invalid, invalid_reason = Observer.Start({
    { owner = {}, entity = {}, label = "bad", events = { "itemget" } },
}, pcall)
assert(invalid == nil and invalid_reason == "invalid_event_source")

local unsupported, unsupported_reason = Observer.Start({
    { owner = entity(940), entity = entity(941), label = "bad-event", events = { "onremove" } },
}, pcall)
assert(unsupported == nil and unsupported_reason == "unsupported_event_name")

local registration_owner = entity(950, "wilson")
local original_listen = registration_owner.ListenForEvent
registration_owner.ListenForEvent = function(self, event_name, callback, source)
    if event_name == "itemlose" then error("registration rejected") end
    return original_listen(self, event_name, callback, source)
end
local registration_failed, registration_reason = Observer.Start({
    { owner = registration_owner, entity = registration_owner,
        label = "partial", events = { "itemget", "itemlose" } },
}, pcall)
assert(registration_failed == nil and registration_reason == "event_listener_registration_failed")
assert(registration_owner:ListenerCount("itemget") == 0)

local bad_limit, bad_limit_reason = Observer.Start({
    { owner = entity(960), entity = entity(961), label = "limit", events = { "itemget" } },
}, pcall, nil, 999)
assert(bad_limit == nil and bad_limit_reason == "invalid_event_limit")

-- A failed cleanup remains retryable; it must never be reported as complete prematurely.
local retry_owner = entity(970, "wilson")
local retry_session = assert(Observer.Start({
    { owner = retry_owner, entity = retry_owner, label = "retry", events = { "itemget" } },
}, pcall))
local original_remove = retry_owner.RemoveEventCallback
local remove_attempts = 0
retry_owner.RemoveEventCallback = function(self, event_name, callback, source)
    remove_attempts = remove_attempts + 1
    if remove_attempts == 1 then error("transient cleanup failure") end
    return original_remove(self, event_name, callback, source)
end
local first_cleanup = assert(Observer.Stop(retry_session))
assert(first_cleanup.cleanup_complete == false and first_cleanup.complete == false)
assert(first_cleanup.pending_cleanup_count == 1)
retry_owner.RemoveEventCallback = original_remove
local second_cleanup = assert(Observer.Stop(retry_session))
assert(second_cleanup.cleanup_complete == true and second_cleanup.complete == true)
assert(second_cleanup.pending_cleanup_count == 0)
assert(retry_owner:ListenerCount("itemget") == 0)

-- Partial registration plus cleanup failure returns a recovery handle as the third result.
local partial_owner = entity(980, "wilson")
local partial_original_listen = partial_owner.ListenForEvent
local partial_original_remove = partial_owner.RemoveEventCallback
local partial_remove_attempts = 0
partial_owner.ListenForEvent = function(self, event_name, callback, source)
    if event_name == "itemlose" then error("second registration rejected") end
    return partial_original_listen(self, event_name, callback, source)
end
partial_owner.RemoveEventCallback = function(self, event_name, callback, source)
    partial_remove_attempts = partial_remove_attempts + 1
    if partial_remove_attempts == 1 then error("partial cleanup failure") end
    return partial_original_remove(self, event_name, callback, source)
end
local partial_result, partial_reason, recovery = Observer.Start({
    { owner = partial_owner, entity = partial_owner,
        label = "partial-recovery", events = { "itemget", "itemlose" } },
}, pcall)
assert(partial_result == nil and partial_reason == "event_listener_registration_failed")
assert(recovery ~= nil and recovery.cleanup_complete == false)
assert(#recovery.listeners == 1 and partial_owner:ListenerCount("itemget") == 1)
partial_owner.RemoveEventCallback = partial_original_remove
local recovered = assert(Observer.Stop(recovery))
assert(recovered.cleanup_complete == true and recovered.pending_cleanup_count == 0)
assert(partial_owner:ListenerCount("itemget") == 0)

local too_many_sources = {}
for index = 1, 17 do
    local source = entity(1000 + index, "wilson")
    too_many_sources[index] = {
        owner = source, entity = source, label = "source-" .. tostring(index), events = { "itemget" },
    }
end
local source_limit, source_limit_reason = Observer.Start(too_many_sources, pcall)
assert(source_limit == nil and source_limit_reason == "too_many_event_sources")

local too_many_listeners = {}
for index = 1, 13 do
    local source = entity(1100 + index, "wilson")
    too_many_listeners[index] = {
        owner = source, entity = source, label = "source-" .. tostring(index),
        events = { "itemget", "itemlose", "stacksizechange", "stacksizepreview" },
    }
end
local listener_limit, listener_limit_reason = Observer.Start(too_many_listeners, pcall)
assert(listener_limit == nil and listener_limit_reason == "too_many_event_listeners")

local no_sources, no_sources_reason = Observer.Start({}, pcall)
assert(no_sources == nil and no_sources_reason == "no_event_sources")

local duplicate_source = entity(1200, "wilson")
local duplicate_subscription, duplicate_subscription_reason = Observer.Start({
    { owner = duplicate_source, entity = duplicate_source, label = "duplicate",
        events = { "itemget", "itemget" } },
}, pcall)
assert(duplicate_subscription == nil
    and duplicate_subscription_reason == "duplicate_event_subscription")

local malformed_entity, malformed_entity_reason = Observer.Start({
    { owner = 42, entity = 42, label = "malformed-entity", events = { "itemget" } },
}, pcall)
assert(malformed_entity == nil and malformed_entity_reason == "invalid_event_source")

-- The player owns the listener; the player and container emit inventory events.
local player_classified = entity(1300, "inventory_classified")
player_classified.IsBusy = function() return false end
local target_classified = entity(1301, "container_classified")
target_classified.IsBusy = function() return false end
local source_player = entity(1302, "wilson")
source_player.replica = { inventory = { classified = player_classified } }
local source_target = entity(1303, "chest")
local target_container_replica = {
    IsBusy = function() return false end,
    IsOpenedBy = function(_, opener) return opener == source_player end,
    classified = target_classified,
}
source_target.replica = { container = target_container_replica }

local replica_sources = assert(Observer.BuildReplicaSources(source_player, source_target, pcall))
assert(#replica_sources == 2)
assert(replica_sources[1].owner == source_player and replica_sources[1].entity == source_player)
assert(replica_sources[2].owner == source_player and replica_sources[2].entity == source_target)
assert(replica_sources[1].label == "player_inventory"
    and replica_sources[2].label == "target_container")

local player_only_sources = assert(Observer.BuildPlayerSources(source_player, pcall))
assert(#player_only_sources == 1
    and player_only_sources[1].owner == source_player
    and player_only_sources[1].entity == source_player
    and player_only_sources[1].events[1] == "itemget"
    and player_only_sources[1].events[2] == "itemlose",
    "pickup observation must subscribe to player inventory events only")
player_classified.IsBusy = function() return true end
local busy_player_only, busy_player_only_reason =
    Observer.BuildPlayerSources(source_player, pcall)
assert(busy_player_only == nil
    and busy_player_only_reason == "player_inventory_classified_busy_or_unknown",
    "pickup observation must fail closed while the player inventory is busy")
player_classified.IsBusy = function() return false end
local missing_inventory_player = entity(1306, "wilson")
local missing_inventory_sources, missing_inventory_reason =
    Observer.BuildPlayerSources(missing_inventory_player, pcall)
assert(missing_inventory_sources == nil
    and missing_inventory_reason == "player_inventory_replica_unavailable",
    "pickup observation must reject a player without an inventory replica")
local invalid_player_only = entity(1307, "wilson")
invalid_player_only.valid = false
local invalid_player_only_sources, invalid_player_only_reason =
    Observer.BuildPlayerSources(invalid_player_only, pcall)
assert(invalid_player_only_sources == nil and invalid_player_only_reason == "invalid_player",
    "pickup observation must reject an invalid player entity")

local replica_session = assert(Observer.Start(replica_sources, pcall))
source_player:Emit("itemget", { item = item, slot = 1, ignore_stacksize_anim = true })
source_target:Emit("itemlose", { slot = 1 })
player_classified:Emit("itemget", { item = item, slot = 2, ignore_stacksize_anim = true })
assert(replica_session.event_count == 2,
    "classified entities are state sources, not the actual inventory event emitters")
local replica_snapshot = assert(Observer.Stop(replica_session))
assert(replica_snapshot.events[1].source == "player_inventory")
assert(replica_snapshot.events[2].source == "target_container")

local tracked_sources = assert(Observer.BuildReplicaSources(
    source_player, source_target, pcall, { item }))
assert(#tracked_sources == 3 and tracked_sources[3].entity == item)
assert(tracked_sources[3].owner == source_player)
assert(tracked_sources[3].events[1] == "stacksizechange")

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
local invalid_player = entity(1304, "wilson")
invalid_player.valid = false
local invalid_sources, invalid_sources_reason =
    Observer.BuildReplicaSources(invalid_player, source_target, pcall)
assert(invalid_sources == nil and invalid_sources_reason == "invalid_player_or_target")

local stale_event_source = entity(1305, "stale")
stale_event_source.valid = false
local stale_source_session, stale_source_reason = Observer.Start({
    { owner = source_player, entity = stale_event_source, label = "stale", events = { "itemget" } },
}, pcall)
assert(stale_source_session == nil and stale_source_reason == "invalid_event_source")

print("ModXpector step event observer tests passed")
