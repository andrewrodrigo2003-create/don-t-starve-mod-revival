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
local third_party_recipe_integration = true
package.preload["mam/config"] = function()
    return {
        int = function(_, _, default) return default or 1 end,
        on = function(key)
            if key == "mam_third_party_recipe_integration" then
                return third_party_recipe_integration
            end
            return true
        end,
    }
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
assert(#filter_calls == 2 and filter_calls[1].filter == "CRAFTING_STATION")
assert(filter_calls[2].filter == "removed:TOOLS" and filter_calls[2].name == "goldenaxe")

local calls_after_first_pass = #filter_calls
assert(guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION"))
assert(#filter_calls == calls_after_first_pass, "repeated station migration must not duplicate filter entries")

-- Invalid target filters must not mutate recipe technology or remove the old filter.
local old_level = AllRecipes.goldenaxe.level
local invalid_ok, invalid_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "MISSING_FILTER")
assert(not invalid_ok and invalid_reason == "invalid-filter")
assert(AllRecipes.goldenaxe.level == old_level, "invalid destination must preserve recipe level")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.goldenaxe ~= nil,
    "invalid destination must preserve the existing station filter")

-- A failing destination API must leave recipe metadata and old filters untouched.
local stable_filter = AllRecipes.goldenaxe.filter
guard.Init(function() end, function() error("simulated AddRecipeToFilter failure") end, function(name, filter)
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)
local add_ok, add_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "MODS")
assert(not add_ok and add_reason == "filter-add-failed")
assert(AllRecipes.goldenaxe.level == old_level, "failed filter add must preserve recipe level")
assert(AllRecipes.goldenaxe.filter == stable_filter, "failed filter add must preserve recipe.filter")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.goldenaxe ~= nil,
    "failed filter add must preserve the previous filter entry")

-- Without RemoveRecipeFromFilter, a migration with an existing old filter must fail closed.
guard.Init(function() end, function(name, filter)
    CRAFTING_FILTERS[filter].default_sort_values[name] = 99
end, nil)
local remove_api_ok, remove_api_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "MODS")
assert(not remove_api_ok and remove_api_reason == "filter-api-unavailable")
assert(AllRecipes.goldenaxe.level == old_level, "missing remove API must preserve recipe level")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.goldenaxe ~= nil,
    "missing remove API must preserve old filter entry")
assert(CRAFTING_FILTERS.MODS.default_sort_values.goldenaxe == nil,
    "missing remove API must not add duplicate destination entry")

-- If removal itself throws after destination insertion, rollback removes the new entry.
guard.Init(function() end, function(name, filter)
    CRAFTING_FILTERS[filter].default_sort_values[name] = 99
end, function(name, filter)
    if filter == "CRAFTING_STATION" then
        error("simulated RemoveRecipeFromFilter failure")
    end
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)
local remove_fail_ok, remove_fail_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "MODS")
assert(not remove_fail_ok and remove_fail_reason == "filter-remove-failed")
assert(AllRecipes.goldenaxe.level == old_level, "failed old-filter removal must preserve recipe level")
assert(AllRecipes.goldenaxe.filter == stable_filter, "failed old-filter removal must preserve recipe.filter")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.goldenaxe ~= nil,
    "failed old-filter removal must preserve old filter entry")
assert(CRAFTING_FILTERS.MODS.default_sort_values.goldenaxe == nil,
    "failed old-filter removal must roll back destination entry")

guard.Init(function() end, function(name, filter)
    CRAFTING_FILTERS[filter].default_sort_values[name] = 99
end, function(name, filter)
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)

assert(not guard.set_station("removed_recipe", TECH.ALCHEMY_ONE, "CRAFTING_STATION"))

-- A recipe modified by another mod is left entirely untouched when the
-- independent third-party integration switch is disabled.
local third_party_ingredients = { { type = "modded_metal", amount = 3 } }
AllRecipes.goldenaxe.ingredients = third_party_ingredients
third_party_recipe_integration = false
local skipped, skipped_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(not skipped and skipped_reason == "third-party-integration-disabled")
assert(AllRecipes.goldenaxe.ingredients == third_party_ingredients, "disabled integration must preserve third-party ingredients")

-- Re-enabling the integration permits the supported station adaptation while
-- still preserving the third-party recipe's ingredient table.
third_party_recipe_integration = true
local adapted, adapted_reason = guard.set_station("goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(adapted and adapted_reason == "applied")
assert(AllRecipes.goldenaxe.ingredients == third_party_ingredients, "enabled integration must preserve third-party ingredients")


-- Seasonal recipes are removed from SPECIAL_EVENT only when explicitly requested.
-- The Mad Scientist Lab must preserve its vanilla ingredients and clear only
-- the exact Hallowed Nights hint while moving to the year-round Structures tab.
TECH.NONE = { ALCHEMY = 0 }
CRAFTING_FILTERS.STRUCTURES = { default_sort_values = {} }
CRAFTING_FILTERS.SPECIAL_EVENT = {
    default_sort_values = { madscience_lab = 1, seasonal_preserved = 2, seasonal_hint = 3 },
}
AllRecipes.madscience_lab = {
    ingredients = { { type = "cutstone", amount = 2 }, { type = "transistor", amount = 2 } },
    level = { SPECIAL_EVENT = 1 },
    filter = "SPECIAL_EVENT",
    hint_msg = "NEEDSHALLOWED_NIGHTS",
}
local lab_ingredients = AllRecipes.madscience_lab.ingredients
local calls_before_lab = #filter_calls
local lab_ok, lab_reason = guard.set_station("madscience_lab", TECH.NONE, "STRUCTURES", {
    remove_special_event = true,
    clear_hint_msg_if = "NEEDSHALLOWED_NIGHTS",
})
assert(lab_ok and lab_reason == "applied")
assert(AllRecipes.madscience_lab.ingredients == lab_ingredients,
    "seasonal station migration must preserve the vanilla ingredient table")
assert(AllRecipes.madscience_lab.filter == "STRUCTURES")
assert(AllRecipes.madscience_lab.level.ALCHEMY == 0)
assert(AllRecipes.madscience_lab.hint_msg == nil,
    "only the matching vanilla Hallowed Nights hint should be cleared")
assert(CRAFTING_FILTERS.STRUCTURES.default_sort_values.madscience_lab ~= nil,
    "year-round Structures filter must receive the Mad Scientist Lab")
assert(CRAFTING_FILTERS.SPECIAL_EVENT.default_sort_values.madscience_lab == nil,
    "explicit seasonal migration must remove the Mad Scientist Lab from SPECIAL_EVENT")
local lab_calls = {}
for i = calls_before_lab + 1, #filter_calls do
    if filter_calls[i].name == "madscience_lab" then
        lab_calls[#lab_calls + 1] = filter_calls[i]
    end
end
assert(#lab_calls == 2, "Mad Scientist Lab migration must add one target and remove one seasonal filter")
assert(lab_calls[1].filter == "STRUCTURES")
assert(lab_calls[2].filter == "removed:SPECIAL_EVENT")

-- Default station migrations must not remove a seasonal filter accidentally.
AllRecipes.seasonal_preserved = {
    ingredients = { { type = "boards", amount = 2 } },
    level = { SPECIAL_EVENT = 1 },
    filter = "SPECIAL_EVENT",
    hint_msg = "OTHER_EVENT_HINT",
}
local preserved_ok = guard.set_station("seasonal_preserved", TECH.NONE, "STRUCTURES")
assert(preserved_ok)
assert(CRAFTING_FILTERS.SPECIAL_EVENT.default_sort_values.seasonal_preserved ~= nil,
    "SPECIAL_EVENT must remain untouched unless remove_special_event is explicit")
assert(AllRecipes.seasonal_preserved.hint_msg == "OTHER_EVENT_HINT",
    "ordinary station migration must preserve unrelated hints")

-- Even with explicit event removal, a non-matching hint must be preserved.
AllRecipes.seasonal_hint = {
    ingredients = { { type = "cutstone", amount = 1 } },
    level = { SPECIAL_EVENT = 1 },
    filter = "SPECIAL_EVENT",
    hint_msg = "OTHER_EVENT_HINT",
}
local mismatch_ok = guard.set_station("seasonal_hint", TECH.NONE, "STRUCTURES", {
    remove_special_event = true,
    clear_hint_msg_if = "NEEDSHALLOWED_NIGHTS",
})
assert(mismatch_ok)
assert(CRAFTING_FILTERS.SPECIAL_EVENT.default_sort_values.seasonal_hint == nil)
assert(AllRecipes.seasonal_hint.hint_msg == "OTHER_EVENT_HINT",
    "hint cleanup must be conditional on the exact vanilla hint value")

print("PASS: War Bench migration preserves metadata and honors the independent third-party recipe switch")
