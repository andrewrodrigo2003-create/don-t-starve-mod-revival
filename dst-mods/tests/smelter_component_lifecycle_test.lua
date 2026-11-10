-- Loads the real smelter component with narrow DST-facing stubs.
-- Run from the repository root:
--   texlua dst-mods/tests/smelter_component_lifecycle_test.lua
-- This covers the component's consumption, interruption, and OnLoad paths;
-- it does not emulate the DST save system or network transport.

local ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = ROOT .. "?.lua;" .. package.path

local config = {
    mam_batch = 1,
    mam_batch_cap = 10,
    mam_batch_time = 25,
    mam_leftovers = 1,
}
local MAMConfig = {
    on = function(name) return config[name] == true or config[name] == 1 end,
    int = function(name, fallback)
        local value = config[name]
        return type(value) == "number" and value or fallback
    end,
}
package.preload["mam/config"] = function() return MAMConfig end

local planned
local smelting = {
    CalculateSmelterPlan = function() return planned end,
    GetSmelterRecipe = function(_, product)
        return product ~= nil and {} or nil
    end,
    ForecastSmelterPlan = function() return { state = "invalid" } end,
}
package.preload["smelting"] = function() return smelting end
package.preload["mam/log"] = function()
    return {
        Try = function(_, fn, ...)
            local ok, result = pcall(fn, ...)
            return ok, result
        end,
        Warn = function() end,
    }
end

function Class(ctor)
    local class = {}
    class.__index = class
    return setmetatable(class, {
        __call = function(_, inst)
            local self = setmetatable({}, class)
            ctor(self, inst)
            return self
        end,
    })
end

FRAMES = 1 / 30

local Smelter = dofile(ROOT .. "components/smelter.lua")
local passed, failed = 0, 0

local function check(name, condition)
    if condition then
        passed = passed + 1
        io.write("PASS  ", name, "\n")
    else
        failed = failed + 1
        io.write("FAIL  ", name, "\n")
    end
end

local function make_item(prefab, count)
    local item = {
        prefab = prefab,
        removed = false,
        components = {},
    }
    function item:IsValid() return not self.removed end
    function item:Remove() self.removed = true end
    if count ~= nil then
        local stackable = { stacksize = count, maxsize = 40 }
        function stackable:IsStack() return self.stacksize > 1 end
        function stackable:StackSize() return self.stacksize end
        function stackable:SetStackSize(value) self.stacksize = value end
        item.components.stackable = stackable
    end
    return item
end

local function make_container(slots)
    local container = {
        slots = slots or {},
        numslots = 4,
        canbeopened = true,
    }
    function container:RemoveItem(item)
        for slot, current in pairs(self.slots) do
            if current == item then
                self.slots[slot] = nil
                break
            end
        end
        return item
    end
    function container:Close() self.closed = true end
    function container:DropEverything()
        self.drop_everything = true
        self.slots = {}
    end
    function container:DestroyContents()
        self.destroy_contents = true
        self.slots = {}
    end
    return container
end

local function make_instance(container)
    local inst = {
        prefab = "metal_smelter",
        components = { container = container },
        deferred = {},
        tags = {},
        mam_plan = {
            set = function(self, value) self.value = value end,
        },
    }
    function inst:DoPeriodicTask()
        return { Cancel = function(self) self.cancelled = true end }
    end
    function inst:DoTaskInTime(delay, fn)
        table.insert(self.deferred, { delay = delay, fn = fn })
        return { Cancel = function(self) self.cancelled = true end }
    end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:GetPosition() return {} end
    return inst
end

local function new_smelter(container)
    local inst = make_instance(container)
    return Smelter(inst), inst
end

-- The component must consume only the exact planned units from each slot.
local first = make_item("copper_ore", 5)
local second = make_item("iron_ore", 2)
local container = make_container({ [1] = first, [2] = second })
local smelter, inst = new_smelter(container)
planned = {
    state = "ready",
    product = "copper_ingot",
    count = 2,
    smelttime = 18,
    consumed = {
        { slot = 1, prefab = "copper_ore", count = 3 },
        { slot = 2, prefab = "iron_ore", count = 2 },
    },
}
local plan_callback = false
smelter.onplanfn = function() plan_callback = true end
check("StartSmelting accepts a valid plan", smelter:StartSmelting())
check("partial stack keeps exact remainder", first.components.stackable.stacksize == 2)
check("fully consumed stack leaves its slot", container.slots[2] == nil and second.removed)
check("start closes and locks the container", container.closed and container.canbeopened == false)
check("start stores product and batch", smelter.product == "copper_ingot" and smelter.batch == 2)
check("start publishes the authoritative plan", inst.mam_plan.value ~= nil and inst.mam_plan.value:find("p|copper_ingot|2|smelting", 1, true) ~= nil)
check("start invokes plan callback", plan_callback)

-- A rejected plan must not consume anything or lock the container.
local untouched = make_item("twigs", 1)
local invalid_container = make_container({ [1] = untouched })
local invalid_smelter = new_smelter(invalid_container)
planned = { state = "invalid", reason = "unknown" }
check("invalid plan cannot start", invalid_smelter:StartSmelting() == false)
check("invalid plan preserves input", invalid_container.slots[1] == untouched and not untouched.removed)
check("invalid plan leaves container open", invalid_container.canbeopened == true and not invalid_container.closed)

-- A stale plan must be rejected before any input is consumed.
local stale_item = make_item("iron_ore", 4)
local stale_container = make_container({ [1] = stale_item })
local stale_smelter = new_smelter(stale_container)
planned = {
    state = "ready",
    product = "copper_ingot",
    count = 1,
    smelttime = 10,
    consumed = { { slot = 1, prefab = "copper_ore", count = 2 } },
}
check("stale receipt cannot start", stale_smelter:StartSmelting() == false)
check("stale receipt preserves all input", stale_container.slots[1] == stale_item
    and stale_item.components.stackable.stacksize == 4)
check("stale receipt leaves machine idle", not stale_smelter.issmelting
    and stale_container.canbeopened == true)

-- Failed output creation preserves only the undelivered remainder for retry.
local output_container = make_container({})
local output_smelter = new_smelter(output_container)
output_smelter.canharvest = true
output_smelter.product = "copper_ingot"
output_smelter.batch = 3
output_smelter.onharvest = nil
local delivered = 0
local harvester = {
    components = {
        inventory = {
            GiveItem = function(_, item)
                delivered = delivered + 1
                item.removed = true
            end,
        },
    },
}
SpawnPrefab = function() return nil end
check("failed output spawn keeps harvest pending", output_smelter:Harvest(harvester) == false)
check("failed output spawn preserves full remainder", output_smelter.canharvest
    and output_smelter.product == "copper_ingot" and output_smelter.batch == 3)
check("failed output spawn delivers nothing", delivered == 0)

SpawnPrefab = function(prefab)
    return {
        prefab = prefab,
        components = {},
        DoTaskInTime = function() end,
    }
end
check("retry harvest succeeds", output_smelter:Harvest(harvester) == true)
check("retry delivers each remaining unit once", delivered == 3)
check("successful retry clears output entitlement", output_smelter.product == nil
    and not output_smelter.canharvest)

-- A missing recipient must not clear a ready output entitlement.
output_smelter.canharvest = true
output_smelter.product = "copper_ingot"
output_smelter.batch = 2
check("harvest without inventory is rejected", output_smelter:Harvest(nil) == false)
check("harvest without inventory preserves output", output_smelter.canharvest
    and output_smelter.product == "copper_ingot" and output_smelter.batch == 2)

-- Interruption follows the leftovers setting in both directions.
config.mam_leftovers = 1
local returned_container = make_container({ [1] = make_item("copper_ore", 2) })
local returned_smelter = new_smelter(returned_container)
returned_smelter.issmelting = true
returned_smelter:ResetSmelter()
check("interruption returns leftovers when enabled", returned_container.drop_everything == true)
check("interruption clears active state", not returned_smelter.issmelting and returned_smelter.product == nil)

config.mam_leftovers = 0
local destroyed_container = make_container({ [1] = make_item("copper_ore", 2) })
local destroyed_smelter = new_smelter(destroyed_container)
destroyed_smelter.issmelting = true
destroyed_smelter:ResetSmelter()
check("interruption destroys leftovers when disabled", destroyed_container.destroy_contents == true)

-- Positive-time saves resume; zero-time saves defer completion until the task.
local active_container = make_container({})
local active_smelter = new_smelter(active_container)
active_smelter:OnLoad({ issmelting = true, product = "copper_ingot", batch = 3, smelttime = 12 })
check("positive-time save resumes", active_smelter.issmelting == true and active_smelter.smelttime == 12)
check("resumed save keeps container locked", active_container.canbeopened == false)

local expired_container = make_container({})
local expired_smelter, expired_inst = new_smelter(expired_container)
expired_smelter:OnLoad({ issmelting = true, product = "copper_ingot", batch = 2, smelttime = 0 })
check("expired save schedules deferred completion", #expired_inst.deferred == 1 and expired_inst.deferred[1].delay == 0)
check("expired save does not complete inline", expired_smelter.issmelting == true and not expired_smelter.canharvest)
local restored_item = make_item("copper_ore", 1)
expired_container.slots[1] = restored_item -- represents container OnLoad finishing first
expired_inst.deferred[1].fn()
check("deferred completion runs after simulated container restore", expired_smelter.canharvest == true)
check("completion applies leftovers-off policy", expired_container.destroy_contents == true)

-- Ready-to-harvest wins over a stale active flag; missing products reset safely.
local ready_container = make_container({})
local ready_smelter = new_smelter(ready_container)
ready_smelter:OnLoad({ canharvest = true, issmelting = true, product = "copper_ingot", batch = 2, smelttime = 0 })
check("ready state takes precedence over stale active flag", ready_smelter.canharvest == true and not ready_smelter.issmelting)

local missing_container = make_container({ [1] = make_item("copper_ore", 1) })
local missing_smelter = new_smelter(missing_container)
missing_smelter:OnLoad({ issmelting = true, product = nil, smelttime = 10 })
check("active save without product resets safely", not missing_smelter.issmelting and missing_smelter.product == nil)
check("missing-product reset applies leftovers-off policy", missing_container.destroy_contents == true)

io.write("\n", passed, " passed; ", failed, " failed\n")
if failed > 0 then
    os.exit(1)
end
