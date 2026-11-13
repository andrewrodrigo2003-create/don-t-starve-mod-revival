package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path

_G.GLOBAL = _G
_G.AllRecipes = {
    goldenaxe = {
        ingredients = { { type = "twigs", amount = 4 }, { type = "goldnugget", amount = 2 } },
        level = { SCIENCE = 1 },
        builder_tag = "crafting_test",
        image = "goldenaxe.tex",
        atlas = "images/inventoryimages.xml",
    },
}
_G.TECH = { ALCHEMY_ONE = { ALCHEMY = 1 } }
_G.CRAFTING_FILTERS = {
    TOOLS = { default_sort_values = { goldenaxe = 1 } },
    MODS = { default_sort_values = {} },
    CRAFTING_STATION = { default_sort_values = {} },
}

package.preload["techtree"] = function()
    return { Create = function(tree) return { ALCHEMY = tree.ALCHEMY } end }
end
package.preload["mam/config"] = function()
    return { int = function(_, _, default) return default or 1 end }
end
package.preload["mam/log"] = function()
    return {
        WarnOnce = function() end,
        Info = function() end,
        Error = function() end,
    }
end

local ingredient_ref = AllRecipes.goldenaxe.ingredients
local builder_tag = AllRecipes.goldenaxe.builder_tag
local image = AllRecipes.goldenaxe.image
local filter_calls = {}
local guard = require("mam/recipe_guard")
guard.Init(function() end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = #filter_calls
end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = "removed:" .. filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)

local ok, reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(ok and reason == "applied")
assert(AllRecipes.goldenaxe.level.ALCHEMY == 1)
assert(AllRecipes.goldenaxe.ingredients == ingredient_ref, "ingredient table must remain untouched")
assert(AllRecipes.goldenaxe.builder_tag == builder_tag, "builder tag must be preserved")
assert(AllRecipes.goldenaxe.image == image, "recipe image must be preserved")
assert(AllRecipes.goldenaxe.filter == "CRAFTING_STATION", "recipe filter property must be updated")
assert(CRAFTING_FILTERS.TOOLS.default_sort_values.goldenaxe == nil, "old filter must not retain the recipe")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.goldenaxe ~= nil, "War Bench filter must receive the recipe")
assert(#filter_calls == 2 and filter_calls[1].filter == "removed:TOOLS")
assert(filter_calls[2].filter == "CRAFTING_STATION" and filter_calls[2].name == "goldenaxe")

local calls_after_first_pass = #filter_calls
assert(guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION"))
assert(#filter_calls == calls_after_first_pass, "repeated station migration must not duplicate filter entries")

assert(not guard.set_station("removed_recipe", TECH.ALCHEMY_ONE, "CRAFTING_STATION"))

print("PASS: War Bench station migration preserves live recipe metadata and ingredients")
