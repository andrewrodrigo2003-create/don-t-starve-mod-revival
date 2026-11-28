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
    return {
        Create = function(tree)
            local result = {}
            for key, value in pairs(tree or {}) do
                result[key] = value
            end
            return result
        end,
    }
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

-- A completed migration must not bypass third-party integration checks if a
-- later mod changes the recipe ingredients before the retry pass.
local post_move_ingredients = { { type = "post_move_modded_metal", amount = 3 } }
AllRecipes.goldenaxe.ingredients = post_move_ingredients
third_party_recipe_integration = false
local post_move_skipped, post_move_skip_reason = guard.set_station(
    "goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(not post_move_skipped and post_move_skip_reason == "third-party-integration-disabled")
assert(AllRecipes.goldenaxe.ingredients == post_move_ingredients,
    "retry must preserve ingredients changed by another mod")
third_party_recipe_integration = true
local post_move_adapted, post_move_adapted_reason = guard.set_station(
    "goldenaxe", TECH.ALCHEMY_ONE, "CRAFTING_STATION")
assert(post_move_adapted and post_move_adapted_reason == "applied")
assert(AllRecipes.goldenaxe.ingredients == post_move_ingredients,
    "retry with integration enabled must preserve the live third-party ingredients")
AllRecipes.goldenaxe.ingredients = ingredient_ref

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


-- Restore call recording after the failure-path cases above rebind the guard
-- with callbacks that intentionally do not write to filter_calls.
guard.Init(function() end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = #filter_calls
end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = "removed:" .. filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)

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


-- Craftbook migration must mutate the existing Recipe, never recreate it via AddRecipe2.
TECH.CRAFTSBOOK_ONE = { CRAFTSBOOK = 1 }
CRAFTING_FILTERS.MODS.default_sort_values.minerhat = 1
CRAFTING_FILTERS.MODS.default_sort_values.seedpouch = 2
CRAFTING_FILTERS.MODS.default_sort_values.purpleamulet = 3

local add_recipe_calls = 0
guard.Init(function()
    add_recipe_calls = add_recipe_calls + 1
    error("Craftbook migration must not recreate an existing Recipe with AddRecipe2")
end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = #filter_calls
end, function(name, filter)
    table.insert(filter_calls, { name = name, filter = "removed:" .. filter })
    CRAFTING_FILTERS[filter].default_sort_values[name] = nil
end)

local function callback_marker() end
local forward_ingredients = { "woodie_boards" }
local minerhat = {
    ingredients = {
        { type = "strawhat", amount = 1 },
        { type = "goldnugget", amount = 1 },
        { type = "fireflies", amount = 1 },
    },
    character_ingredients = {},
    tech_ingredients = {},
    level = { SCIENCE = 2 },
    filter = "ORIGINAL_FILTER",
    name = "minerhat",
    tab = "ORIGINAL_TAB",
    product = "minerhat",
    nameoverride = "Original Miner Hat",
    description = "Original recipe description",
    layeredimagefn = callback_marker,
    imagefn = callback_marker,
    image = "original_minerhat.tex",
    atlas = "images/original.xml",
    fxover = "original_fx",
    placer = "original_placer",
    min_spacing = 2.5,
    testfn = callback_marker,
    overridecandeployrecipeatpointfn = callback_marker,
    canbuild = callback_marker,
    nounlock = false,
    unlocks_from_skin = "SKINUNLOCKS.CRAFTINGSTATION",
    numtogive = 3,
    override_numtogive_fn = callback_marker,
    builder_tag = "original_builder_tag",
    builder_skill = "original_builder_skill",
    no_builder_tag = "original_no_builder_tag",
    no_builder_skill = "original_no_builder_skill",
    forward_ingredients = forward_ingredients,
    sg_state = "original_build_state",
    build_mode = "WATER",
    build_distance = 2,
    no_deconstruction = true,
    decon_ignores_finiteuses = true,
    require_special_event = "hallowed",
    always_allow_buffered_placer = true,
    dropitem = "original_drop",
    actionstr = "ORIGINAL_ACTION",
    recipedisplaynamefn = callback_marker,
    hint_msg = "ORIGINAL_HINT",
    force_hint = true,
    manufactured = true,
    station_tag = "original_station_tag",
    limitedamount = true,
    getlimitedrecipecount = callback_marker,
    source_recipename = "original_source",
    is_deconstruction_recipe = false,
    sortkey = 17,
    rpc_id = 19,
}
AllRecipes.minerhat = minerhat
AllBuilderTaggedRecipes = { minerhat = "original_builder_tag" }
local minerhat_original_ingredients = minerhat.ingredients
local minerhat_character_ingredients = minerhat.character_ingredients
local minerhat_tech_ingredients = minerhat.tech_ingredients
local minerhat_level = minerhat.level
local minerhat_metadata = {
    "name", "tab", "product", "nameoverride", "description", "layeredimagefn", "imagefn", "image", "atlas",
    "fxover", "placer", "min_spacing", "testfn", "overridecandeployrecipeatpointfn", "canbuild",
    "unlocks_from_skin", "numtogive", "override_numtogive_fn", "builder_tag", "builder_skill", "no_builder_tag", "no_builder_skill",
    "forward_ingredients", "sg_state", "build_mode", "build_distance", "no_deconstruction",
    "decon_ignores_finiteuses", "require_special_event", "always_allow_buffered_placer",
    "dropitem", "actionstr", "recipedisplaynamefn", "hint_msg", "force_hint", "manufactured",
    "station_tag", "limitedamount", "getlimitedrecipecount", "source_recipename", "is_deconstruction_recipe", "sortkey", "rpc_id",
}
local minerhat_values = {}
for _, key in ipairs(minerhat_metadata) do
    minerhat_values[key] = minerhat[key]
end
local mam_minerhat_ingredients = {
    { type = "strawhat", amount = 1 },
    { type = "bronze_ingot", amount = 1 },
    { type = "fireflies", amount = 1 },
}
local regate_ok, regate_reason = guard.regate(
    "minerhat", mam_minerhat_ingredients, TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(regate_ok and regate_reason == "applied", "vanilla Craftbook recipe should migrate")
assert(AllRecipes.minerhat == minerhat, "Craftbook migration must preserve the original Recipe object")
assert(minerhat.ingredients == mam_minerhat_ingredients, "MAM-owned vanilla cost override should be applied in place")
assert(minerhat.character_ingredients == minerhat_character_ingredients,
    "character ingredients must remain attached to the original Recipe")
assert(minerhat.tech_ingredients == minerhat_tech_ingredients,
    "tech ingredients must remain attached to the original Recipe")
assert(minerhat.level.CRAFTSBOOK == 1 and minerhat.level.SCIENCE == nil,
    "Craftbook tech level should replace only the intended technology tree")
assert(minerhat.nounlock == true, "Craftbook's explicit nounlock behavior should be applied")
assert(minerhat.filter == "ORIGINAL_FILTER", "AddRecipe2-compatible migration must not rewrite recipe.filter")
assert(CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.minerhat ~= nil,
    "Craftbook recipe must be added to the crafting-station filter")
assert(CRAFTING_FILTERS.MODS.default_sort_values.minerhat == nil,
    "Craftbook migration should remove the old recipe category")
assert(AllBuilderTaggedRecipes.minerhat == "original_builder_tag",
    "existing builder-tag registry entry must remain intact")
for _, key in ipairs(minerhat_metadata) do
    assert(minerhat[key] == minerhat_values[key], "Recipe metadata was changed: " .. key)
end
assert(add_recipe_calls == 0, "Craftbook migration must never call AddRecipe2")

-- UM Beta 6.0.3.9 changes seedpouch ingredients. With integration enabled,
-- retain the live ingredient tables and all metadata while moving the same object.
local seedpouch = {
    ingredients = {
        { type = "slurtle_shellpieces", amount = 2 },
        { type = "waxpaper", amount = 1 },
        { type = "seeds", amount = 2 },
    },
    character_ingredients = { { type = "health", amount = 5 } },
    tech_ingredients = { { type = "SCIENCE", amount = 1 } },
    level = { SCIENCE = 1 },
    filter = "ORIGINAL_SEED_FILTER",
    builder_tag = "um_builder_tag",
    builder_skill = "um_builder_skill",
    no_builder_tag = "um_no_builder_tag",
    no_builder_skill = "um_no_builder_skill",
    product = "seedpouch",
    numtogive = 2,
    canbuild = callback_marker,
    sg_state = "um_build_state",
    station_tag = "um_station",
    require_special_event = "um_event",
    nounlock = false,
}
AllRecipes.seedpouch = seedpouch
local seedpouch_original_ingredients = seedpouch.ingredients
local seedpouch_character_ingredients = seedpouch.character_ingredients
local seedpouch_tech_ingredients = seedpouch.tech_ingredients
local seedpouch_level = seedpouch.level
third_party_recipe_integration = false
local seed_disabled, seed_disabled_reason = guard.regate(
    "seedpouch", { { type = "cutgrass", amount = 99 } }, TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(not seed_disabled and seed_disabled_reason == "third-party-integration-disabled",
    "disabled third-party integration must reject a changed recipe")
assert(AllRecipes.seedpouch == seedpouch and seedpouch.ingredients == seedpouch_original_ingredients,
    "disabled integration must leave the live Recipe and ingredients untouched")
assert(seedpouch.level == seedpouch_level and seedpouch.filter == "ORIGINAL_SEED_FILTER"
    and seedpouch.nounlock == false, "disabled integration must leave recipe state untouched")
third_party_recipe_integration = true
local seed_enabled, seed_enabled_reason = guard.regate(
    "seedpouch", { { type = "cutgrass", amount = 99 } }, TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(seed_enabled and seed_enabled_reason == "kept-others-ingredients",
    "safe integration must retain UM Beta ingredient changes")
assert(AllRecipes.seedpouch == seedpouch, "third-party recipe object must not be replaced")
assert(seedpouch.ingredients == seedpouch_original_ingredients
    and seedpouch.character_ingredients == seedpouch_character_ingredients
    and seedpouch.tech_ingredients == seedpouch_tech_ingredients,
    "all live ingredient groups must remain intact")
assert(seedpouch.level.CRAFTSBOOK == 1 and seedpouch.nounlock == true,
    "only the intended Craftbook tech/nounlock fields should change")
assert(seedpouch.filter == "ORIGINAL_SEED_FILTER", "third-party recipe filter metadata must remain intact")
assert(seedpouch.builder_tag == "um_builder_tag" and seedpouch.builder_skill == "um_builder_skill"
    and seedpouch.no_builder_tag == "um_no_builder_tag" and seedpouch.no_builder_skill == "um_no_builder_skill"
    and seedpouch.product == "seedpouch" and seedpouch.numtogive == 2
    and seedpouch.canbuild == callback_marker and seedpouch.sg_state == "um_build_state"
    and seedpouch.station_tag == "um_station" and seedpouch.require_special_event == "um_event",
    "UM recipe metadata and callbacks must survive Craftbook migration")
assert(add_recipe_calls == 0, "third-party migration must never call AddRecipe2")

-- A metadata-only third-party change is not an ingredient override. Preserve
-- its metadata even while applying the MAM-owned ingredient list.
AllRecipes.purpleamulet = {
    ingredients = {
        { type = "goldnugget", amount = 6 },
        { type = "nightmarefuel", amount = 4 },
        { type = "purplegem", amount = 2 },
    },
    level = { MAGIC = 2 },
    filter = "ORIGINAL_PURPLE_FILTER",
    builder_tag = "metadata_only_builder",
    builder_skill = "metadata_only_skill",
    canbuild = callback_marker,
    numtogive = 4,
    station_tag = "metadata_only_station",
    require_special_event = "metadata_only_event",
    nounlock = false,
}
local purpleamulet = AllRecipes.purpleamulet
local purple_builder_tag = purpleamulet.builder_tag
local purple_canbuild = purpleamulet.canbuild
local purple_ingredients = { { type = "purplegem", amount = 4 } }
local purple_ok = guard.regate("purpleamulet", purple_ingredients, TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(purple_ok and AllRecipes.purpleamulet == purpleamulet,
    "metadata-only third-party recipe must retain its original Recipe object")
assert(purpleamulet.ingredients == purple_ingredients, "MAM cost should apply only to the ingredient field")
assert(purpleamulet.builder_tag == purple_builder_tag and purpleamulet.canbuild == purple_canbuild
    and purpleamulet.numtogive == 4 and purpleamulet.station_tag == "metadata_only_station"
    and purpleamulet.require_special_event == "metadata_only_event",
    "metadata-only third-party properties must survive the ingredient override")

assert(add_recipe_calls == 0, "no Craftbook path may recreate a Recipe with AddRecipe2")

local calls_before_minerhat_retry = #filter_calls
local minerhat_retry_ok = guard.regate(
    "minerhat", mam_minerhat_ingredients, TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(minerhat_retry_ok, "repeated Craftbook migration should remain successful")
assert(#filter_calls == calls_before_minerhat_retry,
    "repeated Craftbook migration must not duplicate filter operations")

-- A filter API failure must happen before the optional ingredient/nounlock commit.
local backpack = {
    ingredients = {
        { type = "cutgrass", amount = 4 },
        { type = "twigs", amount = 4 },
    },
    level = { SCIENCE = 1 },
    filter = "ORIGINAL_BACKPACK_FILTER",
    nounlock = false,
    builder_tag = "backpack_builder",
}
AllRecipes.backpack = backpack
CRAFTING_FILTERS.MODS.default_sort_values.backpack = 4
local backpack_ingredients = backpack.ingredients
local backpack_level = backpack.level
guard.Init(function()
    add_recipe_calls = add_recipe_calls + 1
    error("AddRecipe2 must remain unused")
end, function()
    error("simulated Craftbook filter-add failure")
end, function(name, filter)
    if CRAFTING_FILTERS[filter] ~= nil then
        CRAFTING_FILTERS[filter].default_sort_values[name] = nil
    end
end)
local backpack_ok, backpack_reason = guard.regate(
    "backpack", { { type = "mam_test_material", amount = 1 } },
    TECH.CRAFTSBOOK_ONE, { nounlock = true })
assert(not backpack_ok and backpack_reason == "filter-add-failed",
    "failed Craftbook filter insertion must abort migration")
assert(AllRecipes.backpack == backpack and backpack.ingredients == backpack_ingredients,
    "failed Craftbook migration must not replace the Recipe or its ingredients")
assert(backpack.level == backpack_level and backpack.nounlock == false
    and backpack.filter == "ORIGINAL_BACKPACK_FILTER",
    "failed Craftbook migration must not commit technology, nounlock or filter metadata")
assert(CRAFTING_FILTERS.MODS.default_sort_values.backpack ~= nil
    and CRAFTING_FILTERS.CRAFTING_STATION.default_sort_values.backpack == nil,
    "failed Craftbook migration must preserve the old filter and roll back the target")
assert(add_recipe_calls == 0, "failed Craftbook migration must not call AddRecipe2")

print("PASS: War Bench and Craftbook migration preserve metadata and honor third-party recipe integration")
