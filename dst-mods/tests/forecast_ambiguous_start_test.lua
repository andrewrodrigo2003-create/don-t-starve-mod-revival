-- Regression test for forecast mode 1 ("only certain results").
-- Run from the repository root:
--   texlua dst-mods/tests/forecast_ambiguous_start_test.lua
-- Uses the real smelting and mam/forecast modules; only DST config/log and
-- container replica objects are stubbed.

local ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = ROOT .. "?.lua;" .. package.path

local config_values = {
    mam_batch = 1,
    mam_batch_cap = 10,
    mam_batch_time = 25,
    mam_forecast = 1,
}

local MAMConfig = {}
function MAMConfig.on(name)
    return (config_values[name] or 0) > 0
end
function MAMConfig.int(name, fallback)
    local value = config_values[name]
    return type(value) == "number" and value or fallback
end
package.preload["mam/config"] = function()
    return MAMConfig
end

package.preload["tuning"] = function()
    return true
end

package.preload["mam/log"] = function()
    return {
        Try = function(_, fn, ...)
            local ok, a, b = pcall(fn, ...)
            return ok, a, b
        end,
    }
end

local smelting = require("smelting")
local MAMForecast = require("mam/forecast")

local passed = 0
local failed = 0

local function check(name, condition)
    if condition then
        passed = passed + 1
        io.write("PASS  ", name, "\n")
    else
        failed = failed + 1
        io.write("FAIL  ", name, "\n")
    end
end

-- Inject two equal-priority candidates that are both valid for copper ore.
-- This isolates the UI policy from any random recipe-weight outcome.
local recipes = smelting.recipes.metal_smelter
recipes.mam_test_ambiguous_a = {
    name = "mam_test_ambiguous_a",
    priority = 1000,
    weight = 1,
    cost = { tags = { copper = 1 } },
    test = function(_, names, tags)
        return (tags.copper or 0) >= 1
    end,
}
recipes.mam_test_ambiguous_b = {
    name = "mam_test_ambiguous_b",
    priority = 1000,
    weight = 1,
    cost = { tags = { copper = 1 } },
    test = function(_, names, tags)
        return (tags.copper or 0) >= 1
    end,
}

local item = {
    prefab = "copper_ore",
    components = {},
}
function item:IsValid()
    return true
end

local replica_container = {}
function replica_container:GetItems()
    return { [1] = item }
end

local inst = {
    prefab = "metal_smelter",
    replica = { container = replica_container },
}
function inst:IsValid()
    return true
end

local forecast = smelting.ForecastSmelterPlan("metal_smelter", {
    { prefab = "copper_ore", count = 1, slot = 1 },
})
check("mode 1 suppresses ambiguous result details",
    forecast.state == "ambiguous"
    and forecast.reason == "ambiguous"
    and #forecast.possibilities == 2)

check("ambiguous load remains startable",
    MAMForecast.can_start(inst) == true)

check("ambiguous load communicates uncertainty",
    MAMForecast.button_text(inst) == "Mixed load")

-- A genuinely invalid load must still be blocked.
local invalid_item = {
    prefab = "twigs",
    components = {},
}
function invalid_item:IsValid()
    return true
end
function replica_container:GetItems()
    return { [1] = invalid_item }
end
check("invalid load remains blocked",
    MAMForecast.can_start(inst) == false)

io.write("\n", passed, " passed; ", failed, " failed\n")
if failed > 0 then
    os.exit(1)
end
