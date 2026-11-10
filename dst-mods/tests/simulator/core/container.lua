-- Deterministic container/inventory contract for mod integration scenarios.
-- Semantics are intentionally explicit and version-neutral until checked against a target DST build.
local EventBus = require("simulator.core.event_bus")
local Container = {}
Container.__index = Container

function Container.new(owner, numslots)
    assert(type(numslots) == "number" and numslots >= 1 and numslots % 1 == 0, "positive slot count required")
    return setmetatable({
        inst = owner,
        numslots = numslots,
        slots = {},
        canbeopened = true,
        openers = {},
        events = EventBus.new(),
    }, Container)
end

function Container:GetNumSlots() return self.numslots end
function Container:GetItemInSlot(slot)
    assert(type(slot) == "number" and slot >= 1 and slot <= self.numslots, "slot out of range")
    return self.slots[slot]
end

function Container:GetItems()
    local result = {}
    for slot = 1, self.numslots do
        if self.slots[slot] ~= nil then result[slot] = self.slots[slot] end
    end
    return result
end

function Container:ListenForEvent(event, callback, owner)
    return self.events:Listen(event, callback, owner)
end
function Container:RemoveEventCallback(event, callback_or_token)
    return self.events:Remove(event, callback_or_token)
end

function Container:GiveItem(item, slot)
    if item == nil or not item:IsValid() then return false end
    if slot ~= nil then
        if type(slot) ~= "number" or slot < 1 or slot > self.numslots or slot % 1 ~= 0 then return false end
        local current = self.slots[slot]
        if current == nil then
            self.slots[slot] = item
            self.events:Push("itemget", { item = item, slot = slot })
            return true
        end
        if current:CanStackWith(item) then
            local moved = current:Put(item)
            if moved > 0 then self.events:Push("itemget", { item = current, source = item, slot = slot, count = moved }) end
            if not item:IsValid() then return true end
        end
        return false
    end

    for index = 1, self.numslots do
        local current = self.slots[index]
        if current ~= nil and current:CanStackWith(item) then
            local moved = current:Put(item)
            if moved > 0 then self.events:Push("itemget", { item = current, source = item, slot = index, count = moved }) end
            if not item:IsValid() then return true end
        end
    end
    for index = 1, self.numslots do
        if self.slots[index] == nil then
            self.slots[index] = item
            self.events:Push("itemget", { item = item, slot = index })
            return true
        end
    end
    return false
end

function Container:RemoveItemBySlot(slot)
    if type(slot) ~= "number" or slot < 1 or slot > self.numslots or slot % 1 ~= 0 then return nil end
    local item = self.slots[slot]
    if item == nil then return nil end
    self.slots[slot] = nil
    self.events:Push("itemlose", { item = item, slot = slot })
    return item
end

function Container:RemoveItem(item)
    for slot = 1, self.numslots do
        if self.slots[slot] == item then return self:RemoveItemBySlot(slot) end
    end
    return nil
end

function Container:Open(doer)
    if not self.canbeopened then return false end
    local key = doer or self
    if self.openers[key] then return false end
    self.openers[key] = true
    self.events:Push("onopen", { doer = doer })
    return true
end

function Container:Close(doer)
    local key = doer or self
    if not self.openers[key] then return false end
    self.openers[key] = nil
    self.events:Push("onclose", { doer = doer })
    return true
end

function Container:DropEverything()
    local dropped = {}
    for slot = 1, self.numslots do
        local item = self:RemoveItemBySlot(slot)
        if item ~= nil then dropped[#dropped + 1] = item end
    end
    return dropped
end

function Container:CountItems(prefab)
    local count = 0
    for _, item in pairs(self.slots) do
        if item:IsValid() and (prefab == nil or item.prefab == prefab) then count = count + item:StackSize() end
    end
    return count
end

return Container
