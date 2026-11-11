-- Shared entry point and health check for the DST behavioral simulator.
local Simulator = {
    version = "0.3.0",
    api_profile = "behavioral-core-stategraph-contract-no-game-build",
    evidence_level = "L3-foundation-only",
}

local root = "dst-mods/tests/"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path

Simulator.Scheduler = require("simulator.core.scheduler")
Simulator.EventBus = require("simulator.core.event_bus")
Simulator.Entity = require("simulator.core.entity")
Simulator.Item = require("simulator.core.item")
Simulator.Container = require("simulator.core.container")
Simulator.World = require("simulator.core.world")
Simulator.Network = require("simulator.core.network")
Simulator.StateGraph = require("simulator.core.stategraph")

function Simulator.HealthCheck()
    local world = Simulator.World.new()
    world:RegisterPrefab("health_probe", function() return Simulator.Entity.new("health_probe") end)
    local entity = world:SpawnPrefab("health_probe")
    assert(entity ~= nil and entity:IsValid(), "prefab spawn contract failed")
    local seen = 0
    entity:ListenForEvent("probe", function() seen = seen + 1 end)
    entity:PushEvent("probe")
    assert(seen == 1, "event delivery contract failed")
    local fired = false
    entity:DoTaskInTime(1, function() fired = true end)
    world:AdvanceTime(1)
    assert(fired, "deterministic scheduler contract failed")
    world:RemoveEntity(entity)
    assert(not entity:IsValid(), "entity removal contract failed")
    return {
        version = Simulator.version,
        api_profile = Simulator.api_profile,
        checks = 4,
        evidence_level = Simulator.evidence_level,
    }
end

return Simulator
