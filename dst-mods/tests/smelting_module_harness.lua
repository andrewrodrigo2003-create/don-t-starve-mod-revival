-- Metals and More Reforged: integration harness for the real smelting module.
-- Run from the repository root with: texlua dst-mods/tests/smelting_module_harness.lua
-- Requires Lua 5.1-compatible syntax. No DST engine is loaded; only tuning and
-- the server config are stubbed. smelting.lua and smelting_products.lua are real.

local ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = ROOT .. "?.lua;" .. package.path

package.preload["tuning"] = function()
    return true
end

local config_values = {
    mam_batch = 1,
    mam_batch_cap = 10,
    mam_batch_time = 25,
    mam_forecast = 2,
}

local MAMConfig = {}

function MAMConfig.on(name)
    return config_values[name] == true or config_values[name] == 1
end

function MAMConfig.int(name, fallback)
    local value = config_values[name]
    if type(value) == "number" then
        return value
    end
    return fallback
end

package.preload["mam/config"] = function()
    return MAMConfig
end

local smelting = require("smelting")

local passed = 0
local failed = 0

local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        io.write("PASS  ", name, "\n")
    else
        failed = failed + 1
        io.write("FAIL  ", name)
        if detail ~= nil then
            io.write(" — ", tostring(detail))
        end
        io.write("\n")
    end
end

local function equal(name, actual, expected)
    check(name, actual == expected,
        "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function near(name, actual, expected, epsilon)
    epsilon = epsilon or 0.000001
    check(name, type(actual) == "number" and math.abs(actual - expected) <= epsilon,
        "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function count_by_prefab(list)
    local result = {}
    for _, entry in ipairs(list or {}) do
        result[entry.prefab] = (result[entry.prefab] or 0) + entry.count
    end
    return result
end

local function count_for(list, prefab)
    return count_by_prefab(list)[prefab] or 0
end

local function make_item(prefab, count, slot)
    return { prefab = prefab, count = count or 1, slot = slot or 1 }
end

local function set_config(batch, cap, growth, forecast)
    config_values.mam_batch = batch and 1 or 0
    config_values.mam_batch_cap = cap or 10
    config_values.mam_batch_time = growth or 25
    config_values.mam_forecast = forecast or 2
end

local function plan_for(items)
    -- A fixed random value is safe here: all scenarios below intentionally
    -- leave exactly one highest-priority recipe candidate.
    local old_random = math.random
    math.random = function()
        return 0.5
    end
    local ok, result = pcall(smelting.CalculateSmelterPlan, "metal_smelter", items)
    math.random = old_random
    if not ok then
        error(result)
    end
    return result
end

local function assert_consumption(label, plan, consumed, leftovers)
    for prefab, amount in pairs(consumed) do
        equal(label .. " consumes " .. prefab, count_for(plan.consumed, prefab), amount)
    end
    for prefab, amount in pairs(leftovers) do
        equal(label .. " leaves " .. prefab, count_for(plan.leftovers, prefab), amount)
    end
end

-- Empty and invalid loads must not become free production.
set_config(true, 10, 25, 2)
local empty = plan_for({})
equal("empty load state", empty.state, "invalid")

local invalid = plan_for({ make_item("twigs", 3, 1) })
equal("unrecognized load state", invalid.state, "invalid")

-- Copper: 10 ore at 3 copper per ingot -> 3 outputs, 9 consumed, 1 returned.
local copper_items = { make_item("copper_ore", 10, 1) }
local copper_before = copper_items[1].count
local copper = plan_for(copper_items)
equal("copper batch product", copper.product, "copper_ingot")
equal("copper batch output count", copper.count, 3)
assert_consumption("copper batch", copper, { copper_ore = 9 }, { copper_ore = 1 })
equal("planning does not mutate input stack", copper_items[1].count, copper_before)

-- The hard cap is applied even when enough ingredients are available.
set_config(true, 4, 25, 2)
local capped = plan_for({ make_item("copper_ore", 30, 1) })
equal("configured batch cap", capped.count, 4)
assert_consumption("capped copper", capped, { copper_ore = 12 }, { copper_ore = 18 })

-- Disabling batches preserves one-operation output and base cook time.
set_config(false, 10, 25, 2)
local single = plan_for({ make_item("copper_ore", 10, 1) })
equal("batch disabled output count", single.count, 1)
equal("batch disabled product", single.product, "copper_ingot")
near("batch disabled base cook time", single.smelttime, 15)
assert_consumption("single copper operation", single,
    { copper_ore = 3 }, { copper_ore = 7 })

-- Bronze requires both ingredients for every unit; neither can be reused.
set_config(true, 10, 25, 2)
local bronze = plan_for({
    make_item("copper_ore", 6, 1),
    make_item("iron_ore", 2, 2),
})
equal("bronze batch product", bronze.product, "bronze_ingot")
equal("bronze batch output count", bronze.count, 2)
assert_consumption("bronze batch", bronze,
    { copper_ore = 6, iron_ore = 2 }, {})

-- Moonglass requires one moonrock nugget and two glass per ingot.
local moon = plan_for({
    make_item("moonglass", 6, 1),
    make_item("moonrocknugget", 2, 2),
})
equal("moonglass batch product", moon.product, "moonglass_ingot")
equal("moonglass batch output count", moon.count, 2)
assert_consumption("moonglass batch", moon,
    { moonglass = 4, moonrocknugget = 2 }, { moonglass = 2 })

-- Gold's dual tag requirement must be paid for each produced ingot.
local gold = plan_for({ make_item("goldnugget", 6, 1) })
equal("gold batch product", gold.product, "gold_ingot")
equal("gold batch output count", gold.count, 2)
assert_consumption("gold batch", gold, { goldnugget = 6 }, {})

-- Adamantium has a named iron-ingot prerequisite as well as steel tag cost.
local adamantium = plan_for({
    make_item("nightmarefuel", 15, 1),
    make_item("iron_ingot", 5, 2),
})
equal("adamantium product", adamantium.product, "adamantium_ingot")
equal("adamantium intrinsic cap", adamantium.count, 5)
assert_consumption("adamantium batch", adamantium,
    { nightmarefuel = 15, iron_ingot = 5 }, {})

-- Nitre's alternate gem-fragment route must consume the fragments it uses,
-- while preserving unrelated items that happen to share the container.
local nitre = plan_for({
    make_item("redgem_shard", 2, 1),
    make_item("twigs", 1, 2),
})
equal("nitre fallback product", nitre.product, "nitre")
equal("nitre fallback output count", nitre.count, 1)
assert_consumption("nitre fallback", nitre,
    { redgem_shard = 2 }, { twigs = 1 })

-- A half-metal dust input must be consumed once and retain the original
-- one-output cap; this guards the previously fixed junk_dust regression.
local junk = plan_for({ make_item("copper_dust", 1, 1) })
equal("junk dust product", junk.product, "junk_dust")
equal("junk dust output cap", junk.count, 1)
assert_consumption("junk dust", junk, { copper_dust = 1 }, {})

-- Ore pass-through remains a one-output operation even with a stack.
local ore = plan_for({ make_item("copper_ore", 2, 1) })
equal("ore pass-through product", ore.product, "copper_ore")
equal("ore pass-through cap", ore.count, 1)
assert_consumption("ore pass-through", ore,
    { copper_ore = 1 }, { copper_ore = 1 })

-- Forecast must be side-effect free, deterministic for a single candidate,
-- and use the server-supplied settings rather than the client's local values.
set_config(false, 4, 0, 2)
local forecast_items = { make_item("copper_ore", 6, 1) }
local forecast = smelting.ForecastSmelterPlan("metal_smelter", forecast_items, {
    batch = true,
    cap = 10,
    batch_time = 25,
})
equal("forecast state", forecast.state, "ready")
equal("forecast product", forecast.product, "copper_ingot")
equal("forecast output count uses supplied server cap", forecast.count, 2)
near("forecast time uses supplied server growth", forecast.smelttime, 18.75)
equal("forecast does not mutate input", forecast_items[1].count, 6)
equal("forecast reports deterministic outcome", forecast.deterministic, true)

-- A client configured for batch mode must still forecast a server with it off.
local server_off_forecast = smelting.ForecastSmelterPlan(
    "metal_smelter",
    { make_item("copper_ore", 6, 1) },
    { batch = false, cap = 10, batch_time = 25 }
)
equal("forecast respects server batch-off setting", server_off_forecast.count, 1)
near("forecast batch-off uses base time", server_off_forecast.smelttime, 15)

-- Cover every gem recipe with minimal valid fragment combinations.
-- These checks exercise the real recipe predicates and the real batch planner.
local function gem_case(label, items, product, consumed_prefab, consumed_count)
    local plan = plan_for(items)
    equal(label .. " product", plan.product, product)
    equal(label .. " output count", plan.count, 1)
    assert_consumption(label, plan, { [consumed_prefab] = consumed_count }, {})
end

gem_case("red gem", { make_item("redgem_shard", 4, 1) },
    "redgem", "redgem_shard", 4)
gem_case("blue gem", { make_item("bluegem_shard", 4, 1) },
    "bluegem", "bluegem_shard", 4)
gem_case("purple gem", {
    make_item("redgem_shard", 2, 1),
    make_item("bluegem_shard", 2, 2),
}, "purplegem", "redgem_shard", 2)
local purple_gem = plan_for({
    make_item("redgem_shard", 2, 1),
    make_item("bluegem_shard", 2, 2),
})
assert_consumption("purple gem blue fragments", purple_gem,
    { bluegem_shard = 2 }, {})
gem_case("green gem", { make_item("greengem_shard", 3, 1) },
    "greengem", "greengem_shard", 3)
gem_case("yellow gem", { make_item("yellowgem_shard", 3, 1) },
    "yellowgem", "yellowgem_shard", 3)
gem_case("orange gem", { make_item("orangegem_shard", 3, 1) },
    "orangegem", "orangegem_shard", 3)
gem_case("opal gem", { make_item("redgem_shard", 4, 1) },
    "opalgem", "redgem_shard", 4)

io.write("\n", passed, " passed; ", failed, " failed\n")
if failed > 0 then
    os.exit(1)
end
