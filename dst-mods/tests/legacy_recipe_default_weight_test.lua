-- Regression test for legacy third-party smelter recipes without an explicit weight.
-- Run from the repository root with Lua 5.1:
--   lua5.1 dst-mods/tests/legacy_recipe_default_weight_test.lua

local ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = ROOT .. "?.lua;" .. package.path

package.preload["tuning"] = function()
    return true
end

package.preload["mam/config"] = function()
    return {
        on = function() return true end,
        int = function(_, fallback) return fallback end,
    }
end

local smelting = require("smelting")
local recipe_name = "mam_test_external_default_weight"
smelting.recipes.metal_smelter[recipe_name] = {
    name = recipe_name,
    priority = 1000,
    -- Deliberately omit weight: the public recipe registration path defaults it to 1.
    test = function() return true end,
    cooktime = 7,
}

local old_random = math.random
math.random = function() return 0.5 end
local ok, product, cooktime = pcall(
    smelting.CalculateSmelterRecipe,
    "metal_smelter",
    { "copper_ore" }
)
math.random = old_random

assert(ok, "legacy recipe without weight must not crash: " .. tostring(product))
assert(product == recipe_name, "expected the highest-priority external recipe")
assert(cooktime == 7, "expected the recipe's declared cook time")

print("PASS: legacy recipe without weight uses the documented default")
