-- Pure-Lua regression tests for the Metals and More smelting planner.
-- The game runtime is not started; this validates recipe planning and conservation.

package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path
package.preload["tuning"] = function()
    return {}
end

local config = {
    values = {
        mam_batch = 1,
        mam_batch_cap = 4,
        mam_batch_time = 25,
        mam_forecast = 2,
    },
}

package.preload["mam/config"] = function()
    return {
        on = function(key)
            return (config.values[key] or 0) > 0
        end,
        int = function(key, fallback)
            local value = config.values[key]
            return value ~= nil and value or fallback
        end,
    }
end

local smelting = require("smelting")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function total_for(entries, slot)
    local total = 0
    for _, entry in ipairs(entries or {}) do
        if entry.slot == slot then
            total = total + entry.count
        end
    end
    return total
end

local function assert_conserved(items, plan)
    for _, item in ipairs(items) do
        local consumed = total_for(plan.consumed, item.slot)
        local leftovers = total_for(plan.leftovers, item.slot)
        assert_equal(consumed + leftovers, item.count,
            "material conservation for slot " .. tostring(item.slot))
    end
end

local old_random = math.random
math.random = function()
    return 0
end

-- Batch count, exact consumption, leftovers and proportional time growth.
local copper = {
    { prefab = "copper_ore", count = 8, slot = 1 },
}
local copper_plan = smelting.CalculateSmelterPlan("metal_smelter", copper)
assert_equal(copper_plan.state, "ready", "copper plan state")
assert_equal(copper_plan.product, "copper_ingot", "copper product")
assert_equal(copper_plan.count, 2, "copper batch count")
assert_equal(copper_plan.smelttime, 18.75, "copper batch time")
assert_equal(total_for(copper_plan.consumed, 1), 6, "copper consumed")
assert_equal(total_for(copper_plan.leftovers, 1), 2, "copper leftovers")
assert_conserved(copper, copper_plan)

-- Configured cap is respected even when the input can produce more batches.
local capped = {
    { prefab = "copper_ore", count = 20, slot = 1 },
}
local capped_plan = smelting.CalculateSmelterPlan("metal_smelter", capped)
assert_equal(capped_plan.count, 4, "configured batch cap")
assert_equal(total_for(capped_plan.consumed, 1), 12, "capped copper consumed")
assert_equal(total_for(capped_plan.leftovers, 1), 8, "capped copper leftovers")
assert_conserved(capped, capped_plan)

-- Bronze requires both copper and iron; the limiting ingredient controls count.
local bronze = {
    { prefab = "iron_ore", count = 2, slot = 1 },
    { prefab = "copper_ore", count = 6, slot = 2 },
}
local bronze_plan = smelting.CalculateSmelterPlan("metal_smelter", bronze)
assert_equal(bronze_plan.product, "bronze_ingot", "bronze product")
assert_equal(bronze_plan.count, 2, "bronze batch count")
assert_equal(total_for(bronze_plan.consumed, 1), 2, "bronze iron consumed")
assert_equal(total_for(bronze_plan.consumed, 2), 6, "bronze copper consumed")
assert_conserved(bronze, bronze_plan)

-- Adamantium requires a named iron ingot plus steel tags; named cost limits batch.
local adamantium = {
    { prefab = "iron_ingot", count = 1, slot = 1 },
    { prefab = "nightmarefuel", count = 6, slot = 2 },
}
local adamantium_plan = smelting.CalculateSmelterPlan("metal_smelter", adamantium)
assert_equal(adamantium_plan.product, "adamantium_ingot", "adamantium product")
assert_equal(adamantium_plan.count, 1, "adamantium named-cost batch limit")
assert_equal(total_for(adamantium_plan.consumed, 1), 1, "adamantium named item consumed")
assert_equal(total_for(adamantium_plan.consumed, 2), 3, "adamantium steel consumed")
assert_equal(total_for(adamantium_plan.leftovers, 2), 3, "adamantium steel leftovers")
assert_conserved(adamantium, adamantium_plan)

-- Moonglass consumes both the glass and moon requirement, not only glass.
local moonglass = {
    { prefab = "moonglass", count = 4, slot = 1 },
    { prefab = "moonrocknugget", count = 2, slot = 2 },
}
local moonglass_plan = smelting.CalculateSmelterPlan("metal_smelter", moonglass)
assert_equal(moonglass_plan.product, "moonglass_ingot", "moonglass product")
assert_equal(moonglass_plan.count, 2, "moonglass batch count")
assert_equal(total_for(moonglass_plan.consumed, 1), 4, "moonglass consumed")
assert_equal(total_for(moonglass_plan.consumed, 2), 2, "moon requirement consumed")
assert_conserved(moonglass, moonglass_plan)

-- The nitre alternative path (gem shards below one gem) consumes eligible gems.
local gem_shards = {
    { prefab = "redgem_shard", count = 2, slot = 1 },
}
local nitre_plan = smelting.CalculateSmelterPlan("metal_smelter", gem_shards)
assert_equal(nitre_plan.product, "nitre", "nitre alternative product")
assert_equal(nitre_plan.count, 1, "nitre fallback batch")
assert_equal(total_for(nitre_plan.consumed, 1), 2, "nitre gem shards consumed")
assert_conserved(gem_shards, nitre_plan)

-- Equal-priority outcomes are exposed individually by the forecast.
local ambiguous = {
    { prefab = "iron_ore", count = 1, slot = 1 },
    { prefab = "copper_ore", count = 3, slot = 2 },
    { prefab = "moonrocknugget", count = 1, slot = 3 },
    { prefab = "moonglass", count = 2, slot = 4 },
}
local forecast = smelting.ForecastSmelterPlan("metal_smelter", ambiguous)
assert_equal(forecast.state, "ready", "ambiguous forecast state")
assert_true(forecast.ambiguous, "forecast ambiguity flag")
assert_equal(#forecast.possibilities, 2, "same-priority possibilities")
local outcomes = {}
for _, outcome in ipairs(forecast.outcomes) do
    outcomes[outcome.product] = outcome.count
end
assert_equal(outcomes.bronze_ingot, 1, "bronze forecast outcome")
assert_equal(outcomes.moonglass_ingot, 1, "moonglass forecast outcome")

-- Disabling batch returns to one product per operation.
config.values.mam_batch = 0
local single_plan = smelting.CalculateSmelterPlan("metal_smelter", copper)
assert_equal(single_plan.count, 1, "batch disabled count")
assert_equal(total_for(single_plan.consumed, 1), 3, "single ingot cost")
assert_equal(total_for(single_plan.leftovers, 1), 5, "single ingot leftovers")
assert_conserved(copper, single_plan)
config.values.mam_batch = 1

-- Forecast must not consume randomness or mutate the input.
math.random = function()
    error("forecast must not call math.random")
end
local pure_forecast = smelting.ForecastSmelterPlan("metal_smelter", copper)
assert_equal(pure_forecast.product, "copper_ingot", "pure forecast product")
assert_equal(pure_forecast.count, 2, "pure forecast batch count")
math.random = old_random

-- External recipes without a declared cost retain the legacy consume-all rule.
AddSmelterSmelterRecipe("metal_smelter", {
    name = "test_no_cost",
    priority = 999,
    cooktime = 1,
    test = function(_, names, tags)
        return tags.metal ~= nil and tags.metal >= 1
    end,
})
local external = {
    { prefab = "copper_ore", count = 5, slot = 1 },
}
local external_plan = smelting.CalculateSmelterPlan("metal_smelter", external)
assert_equal(external_plan.product, "test_no_cost", "external no-cost recipe")
assert_equal(external_plan.count, 1, "external recipe single output")
assert_equal(total_for(external_plan.consumed, 1), 5, "external recipe consumes all")
assert_equal(#external_plan.leftovers, 0, "external recipe no leftovers")
assert_conserved(external, external_plan)

-- Empty/unknown load must not manufacture a product.
local invalid = smelting.CalculateSmelterPlan("metal_smelter", {})
assert_equal(invalid.state, "invalid", "empty input invalid state")

print("smelting_plan_test: all planner tests passed")
