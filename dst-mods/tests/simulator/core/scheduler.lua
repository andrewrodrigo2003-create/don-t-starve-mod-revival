-- Deterministic virtual-time scheduler for DST behavioral tests.
-- Lua 5.1 compatible; never sleeps or reads wall-clock time.
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({ now = 0, queue = {}, sequence = 0, running = false }, Scheduler)
end

local function insert_ordered(queue, task)
    local index = #queue + 1
    while index > 1 do
        local previous = queue[index - 1]
        if previous.at < task.at or (previous.at == task.at and previous.sequence < task.sequence) then
            break
        end
        queue[index] = previous
        index = index - 1
    end
    queue[index] = task
end

function Scheduler:Schedule(delay, callback)
    assert(type(delay) == "number" and delay >= 0, "delay must be a non-negative number")
    assert(type(callback) == "function", "callback must be a function")
    self.sequence = self.sequence + 1
    local task = {
        at = self.now + delay,
        sequence = self.sequence,
        callback = callback,
        cancelled = false,
        completed = false,
    }
    insert_ordered(self.queue, task)
    local handle = {}
    function handle:Cancel() task.cancelled = true end
    function handle:IsCancelled() return task.cancelled end
    function handle:IsDone() return task.completed or task.cancelled end
    return handle
end

function Scheduler:Advance(delta, max_callbacks)
    assert(type(delta) == "number" and delta >= 0, "delta must be a non-negative number")
    assert(not self.running, "scheduler cannot be advanced recursively")
    local target = self.now + delta
    local limit = max_callbacks or 10000
    local executed = 0
    self.running = true
    local ok, err = pcall(function()
        while #self.queue > 0 do
            local task = self.queue[1]
            if task.at > target then break end
            table.remove(self.queue, 1)
            self.now = task.at
            if not task.cancelled then
                executed = executed + 1
                assert(executed <= limit, "scheduler callback limit exceeded")
                task.callback()
                task.completed = true
            end
        end
        self.now = target
    end)
    self.running = false
    if not ok then error(err, 0) end
    return executed
end

function Scheduler:PendingCount()
    local count = 0
    for _, task in ipairs(self.queue) do
        if not task.cancelled then count = count + 1 end
    end
    return count
end

return Scheduler
