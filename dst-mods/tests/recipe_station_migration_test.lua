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
end)

local ok, reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(ok and reason == "applied")
assert(AllRecipes.goldenaxe.level.ALCHEMY == 1)
assert(AllRecipes.goldenaxe.ingredients == ingredient_ref, "ingredient table must remain untouched")
assert(AllRecipes.goldenaxe.builder_tag == builder_tag, "builder tag must be preserved")
assert(AllRecipes.goldenaxe.image == image, "recipe image must be preserved")
assert(#filter_calls == 1 and filter_calls[1].name == "goldenaxe")
assert(filter_calls[1].filter == "CRAFTING_STATION")
assert(not guard.set_station("removed_recipe", TECH.ALCHEMY_ONE, "CRAFTING_STATION"))

print("PASS: War Bench station migration preserves live recipe metadata and ingredients")
