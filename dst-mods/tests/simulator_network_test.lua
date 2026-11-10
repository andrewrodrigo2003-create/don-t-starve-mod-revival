-- Server/client replication contracts for the DST behavioral simulator.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local Simulator = require("simulator.bootstrap")
local Network = Simulator.Network

local server = Network.new("server")
local client = Network.new("client")
local dirty = {}
local applied = 0

client:ListenForEvent("netvar_dirty", function(data)
    dirty[#dirty + 1] = data.key .. "=" .. tostring(data.value)
end)
client:ListenForEvent("snapshot_applied", function() applied = applied + 1 end)

assert(server:Set("smelting", true))
assert(server:GetRevision() == 1)
assert(not server:Set("smelting", true), "unchanged writes must not increment revision")
assert(server:GetRevision() == 1)

local first = server:Snapshot()
assert(client:ApplySnapshot(first))
assert(client:Get("smelting") == true)
assert(client:GetRevision() == 1)
assert(#dirty == 1 and dirty[1] == "smelting=true")
assert(applied == 1)

assert(not client:Set("smelting", false), "client must not author replicated state")
assert(client:Get("smelting") == true, "rejected client write changed state")
assert(not client:ApplySnapshot(first), "duplicate snapshot must be rejected")
assert(client:GetRevision() == 1)

assert(server:Set("smelting", false))
assert(server:Set("batch_count", 3))
local second = server:Snapshot()
assert(client:ApplySnapshot(second))
assert(client:Get("smelting") == false)
assert(client:Get("batch_count") == 3)
assert(client:GetRevision() == 3)
assert(applied == 2)

assert(server:Set("batch_count", nil), "server should be able to clear a value")
local third = server:Snapshot()
assert(client:ApplySnapshot(third))
assert(client:Get("batch_count") == nil)
assert(client:GetRevision() == 4)

local forged = { revision = 5, values = { invalid = {} } }
local ok = pcall(function() client:ApplySnapshot(forged) end)
assert(not ok, "non-scalar snapshot value must be rejected")
assert(client:GetRevision() == 4, "invalid snapshot must not partially mutate state")

local server_apply = pcall(function() server:ApplySnapshot(third) end)
assert(server_apply, "server ApplySnapshot should return a rejection, not throw")
local accepted, reason = server:ApplySnapshot(third)
assert(not accepted and reason == "not_replica")

print("DST simulator network: authority, revisions, stale updates and atomic snapshots passed")
