-- Behavioral entity/component lifecycle used by simulator scenarios.
local EventBus = require("simulator.core.event_bus")
local Entity = {}
Entity.__index = Entity

function Entity.new(prefab, id)
    assert(type(prefab) == "string" and prefab ~= "", "prefab name required")
    return setmetatable({
        prefab = prefab,
        GUID = id,
        valid = true,
        components = {},
        events = EventBus.new(),
        tags = {},
        position = { x = 0, y = 0, z = 0 },
    }, Entity)
end

function Entity:IsValid() return self.valid end
function Entity:AddTag(tag) self.tags[tag] = true end
function Entity:RemoveTag(tag) self.tags[tag] = nil end
function Entity:HasTag(tag) return self.tags[tag] == true end
function Entity:AddComponent(name, component)
    assert(self.valid, "cannot add component to removed entity")
    assert(self.components[name] == nil, "component already exists: " .. name)
    self.components[name] = component or {}
    self.components[name].inst = self
    return self.components[name]
end
function Entity:RemoveComponent(name) self.components[name] = nil end
function Entity:ListenForEvent(event, callback, source)
    local bus = source and source.events or self.events
    return bus:Listen(event, callback, self)
end
function Entity:RemoveEventCallback(event, callback, source)
    local bus = source and source.events or self.events
    return bus:Remove(event, callback)
end
function Entity:PushEvent(event, data) return self.events:Push(event, data) end
function Entity:DoTaskInTime(delay, callback)
    assert(self.world ~= nil, "entity is not attached to a simulated world")
    return self.world.scheduler:Schedule(delay, callback)
end
function Entity:GetPosition() return self.position end
function Entity:SetPosition(x, y, z)
    self.position = { x = x or 0, y = y or 0, z = z or 0 }
end
function Entity:Remove()
    if not self.valid then return false end
    self.valid = false
    self.events:Push("onremove", { entity = self })
    self.events:RemoveOwner(self)
    for _, component in pairs(self.components) do
        if type(component.OnRemoveFromEntity) == "function" then
            component:OnRemoveFromEntity()
        end
    end
    self.components = {}
    return true
end

return Entity
