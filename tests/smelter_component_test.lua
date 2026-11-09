-- Minimal Lua 5.1 lifecycle tests for the MAM smelter component.
-- The game runtime is mocked; these tests validate task ownership, not DST gameplay.

package.preload["smelting"] = function()
    return {
        CalculateSmelterPlan = function()
            return {
                state = "ready",
                product = "iron_ingot",
                count = 2,
                smelttime = 5,
                consumed = {},
            }
        end,
        ForecastSmelterPlan = function()
            return { state = "invalid" }
        end,
        GetSmelterRecipe = function()
            return {}
        end,
    }
end

package.preload["mam/config"] = function()
    return {
        on = function()
            return false
        end,
        int = function(_, fallback)
            return fallback
        end,
    }
end

package.preload["mam/log"] = function()
    return {
        Try = function(_, fn, ...)
            local ok, result = pcall(fn, ...)
            return ok, result
        end,
        Warn = function() end,
    }
end

Class = function(ctor)
    local class = {}
    class.__index = class
    return setmetatable(class, {
        __call = function(cls, inst)
            local self = setmetatable({}, cls)
            ctor(self, inst)
            return self
        end,
    })
end

local Smelter = dofile("dst-mods/metals_and_reforged/scripts/components/smelter.lua")

local function make_instance()
    local inst = {
        prefab = "metal_smelter",
        components = {
            container = {
                numslots = 1,
                slots = {},
                canbeopened = true,
            },
        },
        periodic_tasks = {},
        delayed_tasks = {},
        tags = {},
        mam_plan = {
            set = function(self, value)
                self.value = value
            end,
        },
    }

    function inst:DoPeriodicTask(period, fn, initial, ...)
        local task = {
            period = period,
            callback = fn,
            cancelled = false,
            args = { ... },
        }
        function task:Cancel()
            self.cancelled = true
        end
        table.insert(self.periodic_tasks, task)
        return task
    end

    function inst:DoTaskInTime(delay, fn, ...)
        local task = { delay = delay, callback = fn, cancelled = false }
        function task:Cancel()
            self.cancelled = true
        end
        table.insert(self.delayed_tasks, task)
        return task
    end

    function inst:AddTag(tag)
        self.tags[tag] = true
    end

    function inst:RemoveTag(tag)
        self.tags[tag] = nil
    end

    function inst:GetPosition()
        return { x = 0, y = 0, z = 0 }
    end

    local container = inst.components.container
    function container:Close()
        self.closed = true
    end
    function container:DestroyContents()
        self.destroyed = true
    end
    function container:DropEverything()
        self.dropped = true
    end

    local item = {
        prefab = "iron_ore",
        components = {},
        IsValid = function()
            return true
        end,
    }
    container.slots[1] = item

    return inst
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

-- Constructing an idle smelter must not create a permanent polling task.
local idle_inst = make_instance()
local idle_smelter = Smelter(idle_inst)
assert_equal(#idle_inst.periodic_tasks, 0, "idle constructor periodic tasks")
assert_equal(idle_smelter.task, nil, "idle constructor task reference")

-- Starting a batch creates exactly one periodic task; completion cancels it.
assert_equal(idle_smelter:StartSmelting(nil), true, "start smelting")
assert_equal(#idle_inst.periodic_tasks, 1, "one task for active batch")
local batch_task = idle_smelter.task
assert_equal(batch_task.cancelled, false, "batch task active")
idle_smelter:Update(5)
assert_equal(idle_smelter.canharvest, true, "batch completes")
assert_equal(batch_task.cancelled, true, "batch task cancelled on completion")
assert_equal(idle_smelter.task, nil, "task reference cleared after completion")

-- Resuming a saved batch starts polling, and reset cancels it.
local resume_inst = make_instance()
local resume_smelter = Smelter(resume_inst)
resume_smelter.smelttime = 10
resume_smelter:ResumeSmelting()
assert_equal(#resume_inst.periodic_tasks, 1, "resume creates one task")
local resumed_task = resume_smelter.task
resume_smelter:ResetSmelter()
assert_equal(resumed_task.cancelled, true, "reset cancels resumed task")
assert_equal(resume_smelter.task, nil, "reset clears task reference")

-- A ready-to-harvest save should not start a polling task on load.
local ready_inst = make_instance()
local ready_smelter = Smelter(ready_inst)
ready_smelter:OnLoad({ canharvest = true, product = "iron_ingot", batch = 2 })
assert_equal(#ready_inst.periodic_tasks, 0, "ready save has no periodic task")

print("smelter_component_test: all lifecycle tests passed")
