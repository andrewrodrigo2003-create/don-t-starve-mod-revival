-- Minimal world/prefab registry; deliberately not a graphics or physics engine.
local Entity = require("simulator.core.entity")
local World = {}
World.__index = World

function World.new()
    local Scheduler = require("simulator.core.scheduler")
    return setmetatable({
        scheduler = Scheduler.new(),
        prefabs = {},
        entities = {},
        next_guid = 1,
        state = {},
    }, World)
end

function World:RegisterPrefab(name, factory)
    assert(type(name) == "string" and type(factory) == "function", "prefab name and factory required")
    self.prefabs[name] = factory
end

function World:SpawnPrefab(name, ...)
    local factory = self.prefabs[name]
    if factory == nil then return nil end
    local entity = factory(self, ...)
    if entity == nil then return nil end
    entity.world = self
    entity.GUID = entity.GUID or self.next_guid
    self.next_guid = self.next_guid + 1
    self.entities[entity.GUID] = entity
    return entity
end

function World:SpawnEntity(name)
    local prefab = name or "simulated_entity"
    local factory = self.prefabs[prefab]
    if factory ~= nil then return self:SpawnPrefab(prefab) end
    local entity = Entity.new(prefab)
    entity.world = self
    entity.GUID = self.next_guid
    self.next_guid = self.next_guid + 1
    self.entities[entity.GUID] = entity
    return entity
end

function World:AdvanceTime(delta, max_callbacks)
    return self.scheduler:Advance(delta, max_callbacks)
end

function World:CountEntities(prefab)
    local count = 0
    for _, entity in pairs(self.entities) do
        if entity:IsValid() and (prefab == nil or entity.prefab == prefab) then count = count + 1 end
    end
    return count
end

function World:RemoveEntity(entity)
    if entity == nil or not entity:IsValid() then return false end
    local guid = entity.GUID
    entity:Remove()
    self.entities[guid] = nil
    return true
end

return World
