-- Server-authoritative replicated-value contract for behavioral tests.
-- This is a simulator abstraction, not a copy of Klei's netvar implementation.
local EventBus = require("simulator.core.event_bus")
local Network = {}
Network.__index = Network

local function valid_value(value)
    local kind = type(value)
    return value == nil or kind == "boolean" or kind == "number" or kind == "string"
end

local function copy_values(values)
    local copy = {}
    for key, value in pairs(values) do copy[key] = value end
    return copy
end

function Network.new(role)
    assert(role == "server" or role == "client", "network role must be server or client")
    return setmetatable({
        role = role,
        values = {},
        revision = 0,
        events = EventBus.new(),
    }, Network)
end

function Network:Get(key)
    return self.values[key]
end

function Network:GetRevision()
    return self.revision
end

function Network:Set(key, value)
    assert(type(key) == "string" and key ~= "", "netvar key required")
    if self.role ~= "server" then return false, "not_authority" end
    assert(valid_value(value), "simulator netvars accept scalar values only")
    if self.values[key] == value then return false, "unchanged" end

    if value == nil then
        self.values[key] = nil
    else
        self.values[key] = value
    end
    self.revision = self.revision + 1
    self.events:Push("dirty", {
        key = key,
        value = value,
        revision = self.revision,
    })
    return true
end

function Network:Snapshot()
    return {
        revision = self.revision,
        values = copy_values(self.values),
    }
end

function Network:ApplySnapshot(snapshot)
    if self.role ~= "client" then return false, "not_replica" end
    assert(type(snapshot) == "table", "snapshot must be a table")
    assert(type(snapshot.revision) == "number" and snapshot.revision >= 0
        and snapshot.revision % 1 == 0, "snapshot revision must be a non-negative integer")
    assert(type(snapshot.values) == "table", "snapshot values must be a table")
    if snapshot.revision <= self.revision then return false, "stale_snapshot" end

    -- Validate the entire payload before mutating client state.
    for key, value in pairs(snapshot.values) do
        assert(type(key) == "string" and key ~= "", "snapshot contains an invalid key")
        assert(valid_value(value), "snapshot contains a non-scalar value")
    end

    local previous = self.values
    local next_values = copy_values(snapshot.values)
    self.values = next_values
    self.revision = snapshot.revision

    for key, value in pairs(next_values) do
        if previous[key] ~= value then
            self.events:Push("netvar_dirty", {
                key = key, value = value, revision = self.revision,
            })
        end
    end
    for key in pairs(previous) do
        if next_values[key] == nil then
            self.events:Push("netvar_dirty", {
                key = key, value = nil, revision = self.revision,
            })
        end
    end
    self.events:Push("snapshot_applied", { revision = self.revision })
    return true
end

function Network:ListenForEvent(event, callback, owner)
    return self.events:Listen(event, callback, owner)
end

function Network:RemoveEventCallback(event, callback_or_token)
    return self.events:Remove(event, callback_or_token)
end

return Network
