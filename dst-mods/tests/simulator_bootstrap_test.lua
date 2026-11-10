-- Persistent self-test for the reusable DST behavioral simulator core.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local Simulator = require("simulator.bootstrap")
local result = Simulator.HealthCheck()
assert(result.version == "0.2.0")
assert(result.checks == 4)

local Scheduler = Simulator.Scheduler
local scheduler = Scheduler.new()
local order = {}
scheduler:Schedule(2, function() order[#order + 1] = "late" end)
scheduler:Schedule(1, function() order[#order + 1] = "first" end)
local cancelled = scheduler:Schedule(1, function() order[#order + 1] = "cancelled" end)
cancelled:Cancel()
scheduler:Schedule(1, function() order[#order + 1] = "second" end)
assert(scheduler:Advance(2) == 3)
assert(table.concat(order, ",") == "first,second,late", "scheduler order/cancel contract failed")
assert(scheduler:PendingCount() == 0)

local bus = Simulator.EventBus.new()
local owner = {}
local calls = 0
local token = bus:Listen("change", function() calls = calls + 1 end, owner)
bus:Listen("change", function() calls = calls + 10 end, {})
assert(bus:Count("change") == 2)
assert(bus:Remove("change", token) == 1)
assert(bus:Push("change") == 1 and calls == 10)
assert(bus:RemoveOwner({}) == 0)
assert(bus:RemoveOwner(owner) == 0)
assert(bus:Count("change") == 1)

local world = Simulator.World.new()
world:RegisterPrefab("test_machine", function()
    local entity = Simulator.Entity.new("test_machine")
    entity:AddComponent("container", { slots = {} })
    return entity
end)
local machine = world:SpawnPrefab("test_machine")
assert(machine and machine.components.container)
local task_ran = false
machine:DoTaskInTime(0.5, function() task_ran = true end)
world:AdvanceTime(0.49)
assert(not task_ran, "task fired before its deadline")
world:AdvanceTime(0.01)
assert(task_ran, "task did not fire at its deadline")
assert(world:CountEntities("test_machine") == 1)
assert(world:RemoveEntity(machine))
assert(world:CountEntities() == 0)
assert(not world:RemoveEntity(machine), "entity removal must be idempotent")

-- Entity-owned listeners registered on another entity must be detached on removal.
local source = world:SpawnEntity("event_source")
local observer = world:SpawnEntity("observer")
local source_calls = 0
observer:ListenForEvent("external", function() source_calls = source_calls + 1 end, source)
assert(source.events:Count("external") == 1)
world:RemoveEntity(observer)
source:PushEvent("external")
assert(source_calls == 0, "removed observer leaked a listener on a different source")

print("DST simulator bootstrap: core contracts passed; version " .. result.version ..
    "; evidence " .. result.evidence_level)
