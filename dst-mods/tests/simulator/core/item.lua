-- Minimal item/stack behavior for simulator contracts; not a full DST inventory implementation.
local Item = {}
Item.__index = Item

function Item.new(prefab, count, max_stack)
    assert(type(prefab) == "string" and prefab ~= "", "item prefab required")
    count = count or 1
    max_stack = max_stack or 40
    assert(type(count) == "number" and count >= 1 and count % 1 == 0, "stack count must be a positive integer")
    assert(type(max_stack) == "number" and max_stack >= 1 and max_stack % 1 == 0, "max stack must be a positive integer")
    assert(count <= max_stack, "initial stack exceeds max stack")
    return setmetatable({ prefab = prefab, count = count, max_stack = max_stack, valid = true }, Item)
end

function Item:IsValid() return self.valid end
function Item:IsStack() return self.valid and self.count > 1 end
function Item:StackSize() return self.count end
function Item:Get() return self.prefab end
function Item:SetStackSize(count)
    assert(self.valid, "cannot change a removed item")
    assert(type(count) == "number" and count >= 1 and count <= self.max_stack and count % 1 == 0,
        "stack size out of bounds")
    self.count = count
end
function Item:Remove()
    if not self.valid then return false end
    self.valid = false
    self.count = 0
    return true
end
function Item:CanStackWith(other)
    return self.valid and other ~= nil and other.valid and self.prefab == other.prefab
        and self.count < self.max_stack
end
function Item:Put(other)
    assert(self:CanStackWith(other), "items cannot be stacked")
    local moved = math.min(self.max_stack - self.count, other.count)
    self.count = self.count + moved
    other.count = other.count - moved
    if other.count == 0 then other.valid = false end
    return moved
end

return Item
