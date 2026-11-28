-- Persistent self-test for the reusable DST behavioral simulator core.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local Simulator = require("simulator.bootstrap")
local result = Simulator.HealthCheck()
assert(result.version == Simulator.version, "health check must report the loaded simulator version")
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

-- Entity events follow the DST callback shape: (source, data, ...).
local event_world = Simulator.World.new()
local emitter = event_world:SpawnEntity("emitter")
local receiver = event_world:SpawnEntity("receiver")
local observed_source, observed_data, observed_extra
receiver:ListenForEvent("payload", function(source_entity, data, extra)
    observed_source, observed_data, observed_extra = source_entity, data, extra
end, emitter)
local payload = { value = 42 }
emitter:PushEvent("payload", payload, "extra-arg")
assert(observed_source == emitter, "event callback must receive source as first argument")
assert(observed_data == payload and observed_data.value == 42, "event callback must receive original data as second argument")
assert(observed_extra == "extra-arg", "event callback must preserve trailing event arguments")

-- Removing an entity cancels its delayed callbacks and clears its task ownership.
local doomed = event_world:SpawnEntity("doomed")
local cancelled_task_ran = false
local task_handle = doomed:DoTaskInTime(1, function() cancelled_task_ran = true end)
assert(task_handle and not task_handle:IsDone())
event_world:RemoveEntity(doomed)
assert(task_handle:IsCancelled(), "entity removal must cancel owned tasks")
assert(event_world.scheduler:PendingCount() == 0, "cancelled entity task must not remain pending")
event_world:AdvanceTime(1)
assert(not cancelled_task_ran, "removed entity task callback must never execute")
local schedule_after_remove = pcall(function()
    doomed:DoTaskInTime(1, function() end)
end)
assert(not schedule_after_remove, "removed entities must not schedule new tasks")

-- Normal tasks still run once and receive their owning entity.
local live = event_world:SpawnEntity("live")
local callback_owner, normal_calls
normal_calls = 0
live:DoTaskInTime(0.25, function(owner_entity)
    callback_owner = owner_entity
    normal_calls = normal_calls + 1
end)
event_world:AdvanceTime(0.25)
assert(callback_owner == live and normal_calls == 1, "live entity task contract failed")

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
