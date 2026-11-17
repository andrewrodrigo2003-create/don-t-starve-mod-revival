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
        WarnOnce = function() end,
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
TheWorld = { ismastersim = true }
json = { encode = function(value) return tostring(#value) end }

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
        self.dropped = self.dropped or {}
        for _, item in pairs(self.slots) do table.insert(self.dropped, item) end
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
        components = { container = container, lootdropper = { flung = {} } },
        deferred = {},
        tags = {},
        mam_plan = {
            set = function(self, value) self.value = value end,
        },
        mam_recent_results = {
            set = function(self, value) self.value = value end,
        },
    }
    function inst:DoPeriodicTask(period, fn, initial_delay, ...)
        self.periodic_calls = (self.periodic_calls or 0) + 1
        self.last_periodic_fn = fn
        self.last_periodic_args = { ... }
        local task = { cancelled = false }
        function task:Cancel() self.cancelled = true end
        self.last_periodic_task = task
        return task
    end
    function inst:DoTaskInTime(delay, fn)
        table.insert(self.deferred, { delay = delay, fn = fn })
        return { Cancel = function(self) self.cancelled = true end }
    end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:GetPosition() return {} end
    function inst.components.lootdropper:FlingItem(item)
        if self.fail_fling then
            return false
        end
        table.insert(self.flung, item)
        return true
    end
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

-- A plan cannot overdraw a stack through duplicate slot requirements.
planned = {
    state = "ready", product = "copper_ingot", count = 1, smelttime = 5,
    consumed = {
        { slot = 1, prefab = "copper_ore", count = 2 },
        { slot = 1, prefab = "copper_ore", count = 2 },
    },
}
local duplicate_item = make_item("copper_ore", 3)
local duplicate_container = make_container({ [1] = duplicate_item })
local duplicate_smelter = new_smelter(duplicate_container)
check("duplicate slot requirements exceeding stack are rejected",
    duplicate_smelter:StartSmelting() == false)
check("duplicate slot rejection preserves original stack",
    duplicate_container.slots[1] == duplicate_item
        and duplicate_item.components.stackable.stacksize == 3)

-- Failed output creation preserves only the undelivered remainder for retry.
local output_container = make_container({})
local output_smelter = new_smelter(output_container)
output_smelter.canharvest = true
output_smelter.product = "copper_ingot"
output_smelter.batch = 3
local harvest_callbacks = 0
output_smelter.onharvest = function() harvest_callbacks = harvest_callbacks + 1 end
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
check("failed output spawn keeps ready animation callback untouched", harvest_callbacks == 0)

SpawnPrefab = function(prefab)
    return {
        prefab = prefab,
        components = {},
        DoTaskInTime = function() end,
    }
end
check("retry harvest succeeds", output_smelter:Harvest(harvester) == true)
check("retry delivers each remaining unit once", delivered == 3)
check("successful retry invokes harvest animation callback", harvest_callbacks == 1)
check("successful retry clears output entitlement", output_smelter.product == nil
    and not output_smelter.canharvest)

-- A thrown SpawnPrefab error after a partial delivery must preserve only
-- the undelivered remainder; retry must not duplicate the first stack.
local partial_smelter = new_smelter(make_container({}))
partial_smelter.canharvest = true
partial_smelter.product = "copper_ingot"
partial_smelter.batch = 45
local partial_delivered = 0
local partial_callbacks = 0
partial_smelter.onharvest = function() partial_callbacks = partial_callbacks + 1 end
local partial_harvester = {
    components = {
        inventory = {
            GiveItem = function(_, item)
                local stackable = item.components ~= nil and item.components.stackable or nil
                partial_delivered = partial_delivered + (stackable ~= nil and stackable.stacksize or 1)
                item.removed = true
            end,
        },
    },
}
local partial_spawn_attempts = 0
SpawnPrefab = function(prefab)
    partial_spawn_attempts = partial_spawn_attempts + 1
    if partial_spawn_attempts == 2 then
        error("simulated SpawnPrefab constructor failure")
    end
    local item = make_item(prefab, 1)
    item.DoTaskInTime = function() end
    return item
end
check("thrown output spawn preserves pending harvest", partial_smelter:Harvest(partial_harvester) == false)
check("thrown output spawn stores only undelivered remainder",
    partial_smelter.canharvest and partial_smelter.batch == 5)
check("thrown output spawn does not duplicate delivered stack", partial_delivered == 40)
check("thrown output spawn does not call harvest callback", partial_callbacks == 0)
SpawnPrefab = function(prefab)
    local item = make_item(prefab, 1)
    item.DoTaskInTime = function() end
    return item
end
check("retry after thrown spawn error completes pending remainder",
    partial_smelter:Harvest(partial_harvester) == true)
check("retry after thrown spawn error delivers exact total once", partial_delivered == 45)
check("retry after thrown spawn error invokes callback once", partial_callbacks == 1)

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
check("active interruption returns leftovers even when disabled", destroyed_container.drop_everything == true and destroyed_container.destroy_contents ~= true)

-- An active batch is a transaction: consumed ingredients and unconsumed
-- leftovers are both returned when the player cancels it with a hammer.
config.mam_leftovers = 0
local rollback_copper = make_item("copper_ore", 5)
local rollback_iron = make_item("iron_ore", 2)
local rollback_container = make_container({ [1] = rollback_copper, [2] = rollback_iron })
local rollback_smelter, rollback_inst = new_smelter(rollback_container)
planned = {
    state = "ready",
    product = "copper_ingot",
    count = 2,
    smelttime = 30,
    consumed = {
        { slot = 1, prefab = "copper_ore", count = 3 },
        { slot = 2, prefab = "iron_ore", count = 2 },
    },
}
SpawnPrefab = function(prefab) return make_item(prefab, 1) end
check("rollback scenario starts active batch", rollback_smelter:StartSmelting() == true)
check("active receipt records exact consumed inputs",
    #rollback_smelter.active_receipt == 2
        and rollback_smelter.active_receipt[1].prefab == "iron_ore"
        and rollback_smelter.active_receipt[1].count == 2)
local rollback_save = rollback_smelter:OnSave()
check("active receipt is persisted in save data",
    rollback_save.active_receipt ~= nil and #rollback_save.active_receipt == 2)

-- Fail during staging after one prefab was created: nothing may be delivered
-- and the original receipt must remain intact for retry.
local spawn_calls, staged_item = 0, nil
SpawnPrefab = function(prefab)
    spawn_calls = spawn_calls + 1
    if spawn_calls == 1 then
        staged_item = make_item(prefab, 1)
        return staged_item
    end
    return nil
end
check("failed rollback staging does not reset active batch",
    rollback_smelter:ResetSmelter() == false and rollback_smelter.issmelting == true)
check("failed rollback staging removes temporary item",
    staged_item ~= nil and staged_item.removed and #rollback_inst.components.lootdropper.flung == 0)
check("failed rollback staging preserves full receipt",
    #rollback_smelter.active_receipt == 2 and rollback_smelter.active_receipt[1].count == 2)

SpawnPrefab = function(prefab) return make_item(prefab, 1) end
check("hammer cancellation completes rollback", rollback_smelter:ResetSmelter() == true)
local returned = {}
for _, item in ipairs(rollback_inst.components.lootdropper.flung) do
    local count = item.components.stackable ~= nil and item.components.stackable.stacksize or 1
    returned[item.prefab] = (returned[item.prefab] or 0) + count
end
for _, item in ipairs(rollback_container.dropped or {}) do
    local count = item.components.stackable ~= nil and item.components.stackable.stacksize or 1
    returned[item.prefab] = (returned[item.prefab] or 0) + count
end
check("rollback restores all copper including leftover", returned.copper_ore == 5)
check("rollback restores all iron consumed by batch", returned.iron_ore == 2)
check("active cancellation returns leftovers even when option is disabled",
    rollback_container.drop_everything == true and rollback_container.destroy_contents ~= true)
check("successful rollback clears receipt", rollback_smelter.active_receipt == nil)

-- A non-throwing FlingItem rejection must not consume the refund receipt.
local rejected_container = make_container({})
local rejected_smelter, rejected_inst = new_smelter(rejected_container)
rejected_smelter.issmelting = true
rejected_smelter.active_receipt = { { prefab = "iron_ore", count = 3 } }
rejected_inst.components.lootdropper.fail_fling = true
local rejected_spawn
SpawnPrefab = function(prefab)
    rejected_spawn = make_item(prefab, 1)
    return rejected_spawn
end
check("FlingItem false return keeps rollback active",
    rejected_smelter:ResetSmelter() == false and rejected_smelter.issmelting == true)
check("FlingItem false return preserves full receipt",
    rejected_smelter.active_receipt ~= nil
        and rejected_smelter.active_receipt[1].count == 3)
check("FlingItem false return removes undelivered staged item",
    rejected_spawn ~= nil and rejected_spawn.removed)
check("FlingItem false return does not record delivery",
    #rejected_inst.components.lootdropper.flung == 0)
check("failed rollback enters a dedicated retry state",
    rejected_smelter.refund_pending == true
        and rejected_smelter.task ~= nil
        and rejected_smelter.issmelting == true)
check("failed rollback locks the container against new input",
    rejected_container.canbeopened == false and rejected_container.closed == true)
local pending_save = rejected_smelter:OnSave()
check("pending rollback state is persisted",
    pending_save.refund_pending == true and pending_save.active_receipt ~= nil)
check("pending refund cannot be committed as finished output",
    rejected_smelter:DoneSmelting() == false
        and rejected_smelter.canharvest == nil
        and rejected_smelter.active_receipt ~= nil)
rejected_inst.components.lootdropper.fail_fling = false
rejected_smelter:Update(0.5)
check("scheduled update retries and completes the refund",
    rejected_smelter.refund_pending == nil
        and rejected_smelter.active_receipt == nil
        and rejected_smelter.issmelting == nil)
check("successful retry unlocks the container",
    rejected_container.canbeopened == true)
check("successful retry delivers the exact owed amount",
    #rejected_inst.components.lootdropper.flung == 1
        and rejected_inst.components.lootdropper.flung[1].prefab == "iron_ore"
        and rejected_inst.components.lootdropper.flung[1].components.stackable.stacksize == 3)

-- A world reload must restore a pending rollback, keep the container locked,
-- and retry the refund instead of completing the saved smelting timer.
local pending_load_container = make_container({})
local pending_load_smelter, pending_load_inst = new_smelter(pending_load_container)
pending_load_inst.components.lootdropper.fail_fling = true
pending_load_smelter:OnLoad({
    refund_pending = true,
    issmelting = true,
    product = "copper_ingot",
    batch = 1,
    smelttime = 0,
    active_receipt = { { prefab = "gold_ore", count = 2 } },
})
check("load restores pending refund before any output completion",
    pending_load_smelter.refund_pending == true
        and pending_load_smelter.canharvest == nil
        and pending_load_smelter.active_receipt ~= nil)
check("loaded pending refund keeps container locked and schedules retry",
    pending_load_container.canbeopened == false
        and pending_load_smelter.task ~= nil)
pending_load_inst.components.lootdropper.fail_fling = false
pending_load_smelter:Update(0.5)
local loaded_refund_count = 0
for _, item in ipairs(pending_load_inst.components.lootdropper.flung) do
    loaded_refund_count = loaded_refund_count
        + (item.components.stackable ~= nil and item.components.stackable.stacksize or 1)
end
check("loaded pending refund retries without duplicating or losing materials",
    pending_load_smelter.refund_pending == nil
        and pending_load_smelter.active_receipt == nil
        and pending_load_smelter.issmelting == nil
        and loaded_refund_count == 2)

-- Extension callbacks must not interrupt authoritative state transitions.
local callback_container = make_container({ [1] = make_item("copper_ore", 2) })
local callback_smelter = new_smelter(callback_container)
planned = {
    state = "ready", product = "copper_ingot", count = 1, smelttime = 3,
    consumed = { { slot = 1, prefab = "copper_ore", count = 1 } },
}
callback_smelter.startsmeltingfn = function() error("simulated visual callback failure") end
callback_smelter.onplanfn = function() error("simulated plan callback failure") end
check("callback errors do not abort a valid smelting transaction",
    callback_smelter:StartSmelting() == true and callback_smelter.issmelting == true)
callback_smelter.donesmeltingfn = function() error("simulated completion callback failure") end
callback_smelter:DoneSmelting()
check("completion callback error does not block ready state",
    callback_smelter.canharvest == true and callback_smelter.issmelting == nil)
callback_smelter.onharvest = function() error("simulated harvest callback failure") end
SpawnPrefab = function(prefab)
    return { prefab = prefab, components = {}, DoTaskInTime = function() end }
end
local callback_delivered = 0
local callback_harvester = { components = { inventory = {
    GiveItem = function(_, item) callback_delivered = callback_delivered + 1; item.removed = true end,
} } }
check("harvest callback error does not prevent output reset",
    callback_smelter:Harvest(callback_harvester) == true
        and callback_smelter.product == nil and callback_smelter.canharvest == nil)
check("harvest callback error still delivers output", callback_delivered == 1)

-- Restore stack-capable prefabs for the save/load receipt tests below.
SpawnPrefab = function(prefab) return make_item(prefab, 1) end

-- A completed batch commits its receipt; later reset/harvest must not refund it.
local committed_container = make_container({})
local committed_smelter, committed_inst = new_smelter(committed_container)
committed_smelter.issmelting = true
committed_smelter.active_receipt = { { prefab = "iron_ore", count = 4 } }
committed_smelter:DoneSmelting()
check("completion commits and clears active receipt", committed_smelter.active_receipt == nil)
committed_smelter:ResetSmelter()
check("committed batch is never refunded", #committed_inst.components.lootdropper.flung == 0)

-- Receipt saved during smelting is restored and can still be refunded.
local loaded_container = make_container({})
local loaded_smelter, loaded_inst = new_smelter(loaded_container)
loaded_smelter:OnLoad({
    issmelting = true,
    product = "copper_ingot",
    batch = 1,
    smelttime = 10,
    active_receipt = { { prefab = "gold_ore", count = 3 } },
})
check("active receipt is restored from save", loaded_smelter.active_receipt ~= nil
    and loaded_smelter.active_receipt[1].prefab == "gold_ore"
    and loaded_smelter.active_receipt[1].count == 3)
check("loaded active receipt can be refunded", loaded_smelter:ResetSmelter() == true)
local loaded_returned = loaded_inst.components.lootdropper.flung[1]
check("loaded rollback returns exact saved quantity",
    loaded_returned ~= nil and loaded_returned.prefab == "gold_ore"
        and loaded_returned.components.stackable.stacksize == 3)

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

-- Idle lifecycle: no permanent timer per furnace. Poll only while smelting.
local idle_container = make_container({})
local idle_smelter, idle_inst = new_smelter(idle_container)
check("new idle smelter creates no periodic task", idle_smelter.task == nil)
check("new idle smelter performs no polling", (idle_inst.periodic_calls or 0) == 0)

local running_container = make_container({})
local running_smelter, running_inst = new_smelter(running_container)
running_smelter.issmelting = true
running_smelter.product = "copper_ingot"
running_smelter.smelttime = 5
running_smelter:ResumeSmelting()
check("resumed active smelter starts one periodic task",
    running_smelter.task ~= nil and running_inst.periodic_calls == 1)
local running_task = running_smelter.task
running_smelter:DoneSmelting()
check("completed smelter cancels periodic task",
    running_task.cancelled == true and running_smelter.task == nil)

local reset_container = make_container({})
local reset_smelter, reset_inst = new_smelter(reset_container)
reset_smelter.issmelting = true
reset_smelter.product = "copper_ingot"
reset_smelter.smelttime = 10
reset_smelter:ResumeSmelting()
local reset_task = reset_smelter.task
reset_smelter:ResetSmelter()
check("reset smelter cancels periodic task",
    reset_task.cancelled == true and reset_smelter.task == nil)
check("reset smelter does not leave a polling task",
    (reset_inst.periodic_calls or 0) == 1)



-- The guide keeps only the three latest successfully completed smelting results.
local history_smelter, history_inst = new_smelter(make_container({}))
history_smelter.product = "copper_ingot"
history_smelter.batch = 2
history_smelter.issmelting = true
history_smelter:DoneSmelting()
history_smelter.canharvest = nil
history_smelter.product = "iron_ingot"
history_smelter.batch = 1
history_smelter.issmelting = true
history_smelter:DoneSmelting()
history_smelter.canharvest = nil
history_smelter.product = "gold_ingot"
history_smelter.batch = 3
history_smelter.issmelting = true
history_smelter:DoneSmelting()
history_smelter.canharvest = nil
history_smelter.product = "bronze_ingot"
history_smelter.batch = 4
history_smelter.issmelting = true
history_smelter:DoneSmelting()
check("forge history keeps the latest three results",
    #history_smelter.recent_results == 3
        and history_smelter.recent_results[1].product == "bronze_ingot"
        and history_smelter.recent_results[2].product == "gold_ingot"
        and history_smelter.recent_results[3].product == "iron_ingot")
check("forge history is replicated to the book UI", history_inst.mam_recent_results.value == "3")
check("repeated completion cannot duplicate the same result", history_smelter:DoneSmelting() == false
    and #history_smelter.recent_results == 3)
local history_save = history_smelter:OnSave()
local history_loaded, history_loaded_inst = new_smelter(make_container({}))
history_loaded:OnLoad(history_save)
check("forge history survives save/load",
    #history_loaded.recent_results == 3
        and history_loaded.recent_results[1].product == "bronze_ingot")
check("loaded forge history is republished", history_loaded_inst.mam_recent_results.value == "3")


-- Robot auto-harvest must preserve the ready output if either the preflight
-- template or a later output stack cannot be constructed.
local robot_config_previous = config.mam_robot_smelting
config.mam_robot_smelting = 1
local robot_entity = {
    prefab = "chester",
    components = {
        fueled = { IsEmpty = function() return false end },
        inventoryitem = { IsHeld = function() return false end },
    },
}
function robot_entity:GetCurrentPlatform() return nil end
local robot_storage = {
    prefab = "marble_chest",
    components = {},
}
function robot_storage:GetCurrentPlatform() return nil end
function robot_storage:GetDistanceSqToInst() return 1 end
local robot_storage_container = {
    inst = robot_storage, type = "chest", canbeopened = true, numslots = 25,
    delivered = {},
}
robot_storage.components.container = robot_storage_container
function robot_storage_container:CanAcceptCount(_, count) return count end
function robot_storage_container:GiveItem(item)
    table.insert(self.delivered, item)
    item.removed = true
    return true
end
local robot_world = {
    FindEntities = function(_, _, _, _, _, musttags)
        if musttags[1] == "storagerobot" then return { robot_entity } end
        if musttags[1] == "_container" then return { robot_storage } end
        return {}
    end,
}
TheSim = robot_world
local robot_smelter, robot_inst = new_smelter(make_container({}))
robot_inst.Transform = { GetWorldPosition = function() return 0, 0, 0 end }
robot_inst.GetCurrentPlatform = function() return nil end
robot_inst.components.container.inst = robot_inst
robot_smelter.canharvest = true
robot_smelter.product = "copper_ingot"
robot_smelter.batch = 3
local template_spawn_calls = 0
SpawnPrefab = function()
    template_spawn_calls = template_spawn_calls + 1
    error("simulated robot output constructor failure")
end
check("robot auto-harvest catches template constructor errors",
    robot_smelter:TryAutoHarvestToStorage() == false)
check("robot template error preserves full ready entitlement",
    robot_smelter.canharvest and robot_smelter.product == "copper_ingot"
        and robot_smelter.batch == 3 and #robot_storage_container.delivered == 0)

local robot_partial, robot_partial_inst = new_smelter(make_container({}))
robot_partial_inst.Transform = robot_inst.Transform
robot_partial_inst.GetCurrentPlatform = robot_inst.GetCurrentPlatform
robot_partial_inst.components.container.inst = robot_partial_inst
robot_partial.canharvest = true
robot_partial.product = "copper_ingot"
robot_partial.batch = 45
local robot_spawn_calls = 0
local robot_delivered = 0
local function robot_output(prefab, stack_count)
    local item = make_item(prefab, stack_count)
    item.components.stackable.maxsize = 40
    item.components.inventoryitem = {
        OnDropped = function() item.dropped = true end,
    }
    item.Transform = { SetPosition = function() end }
    item.DoTaskInTime = function() end
    return item
end
SpawnPrefab = function(prefab)
    robot_spawn_calls = robot_spawn_calls + 1
    if robot_spawn_calls == 3 then
        error("simulated second robot stack constructor failure")
    end
    return robot_output(prefab, 1)
end
robot_storage_container.GiveItem = function(self, item)
    local count = item.components.stackable ~= nil and item.components.stackable.stacksize or 1
    robot_delivered = robot_delivered + count
    table.insert(self.delivered, item)
    item.removed = true
    return true
end
check("robot auto-harvest catches a later stack constructor error",
    robot_partial:TryAutoHarvestToStorage() == false)
check("robot partial failure stores only the undelivered remainder",
    robot_partial.canharvest and robot_partial.batch == 5
        and robot_partial.product == "copper_ingot" and robot_delivered == 40)
robot_spawn_calls = 0
SpawnPrefab = function(prefab) return robot_output(prefab, 1) end
check("robot auto-harvest retry completes the pending remainder",
    robot_partial:TryAutoHarvestToStorage() == true)
check("robot retry delivers exactly the original batch once",
    robot_delivered == 45 and robot_partial.product == nil
        and robot_partial.canharvest == nil)
config.mam_robot_smelting = robot_config_previous
TheSim = nil


-- Robot-fed batches must move only the planner-selected ingredients from a
-- compatible nearby chest, and a failed transfer must restore the exact source.
local function robot_test_container(entity, slots, fail_on_give)
    local container = {
        inst = entity, type = "chest", canbeopened = true, numslots = 4,
        slots = slots or {}, give_calls = 0, fail_on_give = fail_on_give,
    }
    function container:RemoveItem(item, all)
        for slot = 1, self.numslots do
            if self.slots[slot] == item then
                local stackable = item.components.stackable
                if not all and stackable ~= nil and stackable:StackSize() > 1 then
                    stackable:SetStackSize(stackable:StackSize() - 1)
                    return make_item(item.prefab, 1)
                end
                self.slots[slot] = nil
                return item
            end
        end
        return nil
    end
    function container:GiveItem(item)
        self.give_calls = self.give_calls + 1
        if self.fail_on_give == self.give_calls then return false end
        for slot = 1, self.numslots do
            local current = self.slots[slot]
            if current ~= nil and current.prefab == item.prefab
                and current.components.stackable ~= nil and item.components.stackable ~= nil then
                current.components.stackable:SetStackSize(
                    current.components.stackable:StackSize() + item.components.stackable:StackSize())
                item.removed = true
                return true
            end
        end
        for slot = 1, self.numslots do
            if self.slots[slot] == nil then
                self.slots[slot] = item
                return true
            end
        end
        return false
    end
    function container:Close() self.closed = true end
    function container:DropEverything()
        self.dropped = true
        self.slots = {}
    end
    return container
end
local function robot_test_entity(prefab)
    local entity = { prefab = prefab, components = {} }
    function entity:IsValid() return true end
    function entity:GetCurrentPlatform() return nil end
    function entity:GetDistanceSqToInst() return 1 end
    return entity
end
local feed_robot = robot_test_entity("chester")
feed_robot.components.fueled = { IsEmpty = function() return false end }
feed_robot.components.inventoryitem = { IsHeld = function() return false end }
local feed_source = robot_test_entity("marble_chest")
local feed_source_stack = make_item("copper_ore", 3)
local feed_source_container = robot_test_container(feed_source, { [1] = feed_source_stack })
feed_source.components.container = feed_source_container
local function configure_robot_world(source)
    TheSim = {
        FindEntities = function(_, _, _, _, _, musttags)
            if musttags[1] == "storagerobot" then return { feed_robot } end
            if musttags[1] == "_container" then return { source } end
            return {}
        end,
    }
end
config.mam_robot_smelting = 1
planned = {
    state = "ready", product = "copper_ingot", count = 1, smelttime = 30,
    consumed = { { slot = 1, prefab = "copper_ore", count = 3 } },
}
local feed_machine_container = robot_test_container(nil, {})
local feed_smelter, feed_inst = new_smelter(feed_machine_container)
feed_machine_container.inst = feed_inst
feed_inst.Transform = { GetWorldPosition = function() return 0, 0, 0 end }
feed_inst.GetCurrentPlatform = function() return nil end
configure_robot_world(feed_source)
check("robot feeder starts a batch from a nearby compatible chest",
    feed_smelter:TryStartRobotBatch() == true)
check("robot feeder transfers only the planned ingredients and starts smelting",
    feed_smelter.issmelting == true and feed_smelter.product == "copper_ingot"
        and feed_source_container.slots[1] == nil
        and next(feed_machine_container.slots) == nil)

local rollback_source = robot_test_entity("cold_safe")
local rollback_source_stack = make_item("copper_ore", 3)
local rollback_source_container = robot_test_container(rollback_source, { [1] = rollback_source_stack })
rollback_source.components.container = rollback_source_container
local rollback_machine_container = robot_test_container(nil, {}, 2)
local rollback_feed_smelter, rollback_feed_inst = new_smelter(rollback_machine_container)
rollback_machine_container.inst = rollback_feed_inst
rollback_feed_inst.Transform = feed_inst.Transform
rollback_feed_inst.GetCurrentPlatform = feed_inst.GetCurrentPlatform
configure_robot_world(rollback_source)
check("robot feeder rejects a failed container transfer",
    rollback_feed_smelter:TryStartRobotBatch() == false)
check("failed robot transfer restores exact source stack and empties smelter",
    rollback_source_container.slots[1] == rollback_source_stack
        and rollback_source_stack.components.stackable:StackSize() == 3
        and next(rollback_machine_container.slots) == nil
        and rollback_feed_smelter.issmelting == nil)
config.mam_robot_smelting = robot_config_previous
TheSim = nil

io.write("\n", passed, " passed; ", failed, " failed\n")
if failed > 0 then
    os.exit(1)
end
