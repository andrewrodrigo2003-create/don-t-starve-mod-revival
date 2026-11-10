-- Small deterministic event contract with explicit listener ownership.
local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    return setmetatable({ listeners = {}, sequence = 0 }, EventBus)
end

function EventBus:Listen(event, callback, owner)
    assert(type(event) == "string" and event ~= "", "event name required")
    assert(type(callback) == "function", "event callback required")
    self.sequence = self.sequence + 1
    local listener = { callback = callback, owner = owner, sequence = self.sequence, active = true }
    local bucket = self.listeners[event] or {}
    self.listeners[event] = bucket
    bucket[#bucket + 1] = listener
    return listener
end

function EventBus:Remove(event, callback_or_token)
    local bucket = self.listeners[event]
    if bucket == nil then return 0 end
    local removed = 0
    for _, listener in ipairs(bucket) do
        if listener.active and (listener == callback_or_token or listener.callback == callback_or_token) then
            listener.active = false
            removed = removed + 1
        end
    end
    return removed
end

function EventBus:RemoveOwner(owner)
    local removed = 0
    for _, bucket in pairs(self.listeners) do
        for _, listener in ipairs(bucket) do
            if listener.active and listener.owner == owner then
                listener.active = false
                removed = removed + 1
            end
        end
    end
    return removed
end

function EventBus:Push(event, data)
    local bucket = self.listeners[event]
    if bucket == nil then return 0 end
    local snapshot = {}
    for i, listener in ipairs(bucket) do snapshot[i] = listener end
    local delivered = 0
    for _, listener in ipairs(snapshot) do
        if listener.active then
            delivered = delivered + 1
            listener.callback(data or {})
        end
    end
    local compact = {}
    for _, listener in ipairs(bucket) do
        if listener.active then compact[#compact + 1] = listener end
    end
    self.listeners[event] = #compact > 0 and compact or nil
    return delivered
end

function EventBus:Count(event)
    if event ~= nil then
        local count = 0
        for _, listener in ipairs(self.listeners[event] or {}) do
            if listener.active then count = count + 1 end
        end
        return count
    end
    local total = 0
    for _, bucket in pairs(self.listeners) do
        for _, listener in ipairs(bucket) do
            if listener.active then total = total + 1 end
        end
    end
    return total
end

return EventBus
