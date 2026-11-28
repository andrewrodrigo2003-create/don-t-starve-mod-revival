-- Integrated Metals and More forge scenario using the shared simulator
-- and the real mod smelting planner + real Smelter component.
-- L3 behavioral integration; not a Klei engine/runtime test.
local TEST_ROOT = "dst-mods/tests/"
local MOD_ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = TEST_ROOT .. "?.lua;" .. TEST_ROOT .. "?/init.lua;"
    .. MOD_ROOT .. "?.lua;" .. MOD_ROOT .. "?/init.lua;" .. package.path

local Simulator = require("simulator.bootstrap")
local config = {
    mam_batch = true,
    mam_batch_cap = 10,
    mam_batch_time = 25,
    mam_leftovers = true,
    mam_forecast = 2,
}
package.preload["tuning"] = function() return {} end
package.preload["mam/config"] = function()
    return {
        on = function(name) return config[name] == true end,
        int = function(name, fallback)
            local value = config[name]
            return type(value) == "number" and value or fallback
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

local Smelter = dofile(MOD_ROOT .. "components/smelter.lua")
local smelting = require("smelting")
local world = Simulator.World.new()
local server_net = Simulator.Network.new("server")
local client_net = Simulator.Network.new("client")

local function make_item(prefab, count, max_stack)
    local item = Simulator.Item.new(prefab, count, max_stack)
    item.components = {}
    item.components.stackable = {
        maxsize = max_stack or 40,
        stacksize = item:StackSize(),
        IsStack = function() return item:IsStack() end,
        StackSize = function() return item:StackSize() end,
        SetStackSize = function(self, value)
            item:SetStackSize(value)
            self.stacksize = value
        end,
    }
    function item:DoTaskInTime(delay, fn)
        return world.scheduler:Schedule(delay, fn)
    end
    return item
end

local forge = world:SpawnEntity("metal_smelter")
local container = Simulator.Container.new(forge, 4)
forge.components.container = container
forge.mam_plan = {
    set = function(_, value)
        forge.plan_string = value
        server_net:Set("smelter_plan", value)
    end,
}
function forge:DoPeriodicTask(delay, fn, initial_delay, ...)
    local args = { ... }
    return self.world.scheduler:Schedule(delay, function()
        fn(self, unpack(args))
    end)
end
function forge:GetPosition() return { x = 0, y = 0, z = 0 } end

local smelter = Smelter(forge)
forge.components.smelter = smelter

local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local ore = make_item("copper_ore", 7, 40)
assert(container:GiveItem(ore, 1))
local forecast = smelting.ForecastSmelterPlan("metal_smelter", smelter:GetItems())
check("real smelting planner predicts a copper-family result",
    forecast ~= nil and forecast.state == "ready"
        and (forecast.product == "copper_ingot" or forecast.product == "copper_ore"))

local started = smelter:StartSmelting()
check("real smelter component starts from real planner output", started == true)
check("exact recipe consumption leaves the planned remainder",
    ore:IsValid() and ore:StackSize() == 1)
check("server publishes processing phase", forge.plan_string ~= nil
    and forge.plan_string:find("|smelting", 1, true) ~= nil)
assert(client_net:ApplySnapshot(server_net:Snapshot()))
check("client receives server-authoritative processing state",
    client_net:Get("smelter_plan") == forge.plan_string)
check("container locks while processing", container.canbeopened == false)

smelter:Update(smelter.smelttime)
check("processing completes and sets ready-to-harvest state",
    smelter.canharvest == true and smelter.issmelting == nil)
check("server publishes harvest phase",
    forge.plan_string ~= nil and forge.plan_string:find("|harvest", 1, true) ~= nil)
assert(client_net:ApplySnapshot(server_net:Snapshot()))
check("client receives completed phase",
    client_net:Get("smelter_plan") == forge.plan_string)

SpawnPrefab = function(prefab)
    return make_item(prefab, 1, 20)
end

local received = {}
local player = {
    components = {
        inventory = {
            GiveItem = function(_, item)
                received[#received + 1] = item
                return true
            end,
        },
    },
}
local harvested = smelter:Harvest(player)
check("harvest succeeds after processing", harvested == true)
local total_output = 0
for _, item in ipairs(received) do total_output = total_output + item:StackSize() end
check("inventory receives exactly the planned product quantity",
    total_output == (forecast.count or 1))
check("harvest resets machine after delivery",
    smelter.canharvest == nil and smelter.product == nil)
check("unconsumed materials are ejected instead of silently deleted",
    container:CountItems("copper_ore") == 0 and ore:IsValid() == true)

-- Save/load contract: a ready batch remains ready and is not processed twice.
local save_data = {
    canharvest = true,
    product = "copper_ingot",
    batch = 2,
    smelttime = 0,
}
local restored = world:SpawnEntity("metal_smelter")
local restored_container = Simulator.Container.new(restored, 4)
restored.components.container = restored_container
restored.mam_plan = {
    set = function(_, value) restored.plan_string = value end,
}
function restored:DoPeriodicTask(delay, fn)
    return self.world.scheduler:Schedule(delay, function() fn(self) end)
end
function restored:GetPosition() return { x = 0, y = 0, z = 0 } end
local restored_smelter = Smelter(restored)
restored.components.smelter = restored_smelter
restored_smelter:OnLoad(save_data)
check("ready save restores without restarting the smelting timer",
    restored_smelter.canharvest == true
        and restored_smelter.issmelting == nil
        and restored_smelter.batch == 2)
check("restored ready save keeps container locked",
    restored_container.canbeopened == false)

print("\nForge integration: " .. passed .. " passed; " .. failed .. " failed")
if failed > 0 then os.exit(1) end
