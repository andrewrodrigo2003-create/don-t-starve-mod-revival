-- Retry contracts for guarded recipe migrations.
-- Run from the repository root with Lua 5.1:
--   lua5.1 dst-mods/tests/recipe_application_retry_test.lua

local passed = 0
local function check(condition, label)
    assert(condition, label)
    passed = passed + 1
end

local function run_case(module_path, method_name, expected_minimum)
    local sim_callbacks = {}
    local prefab_callbacks = {}
    local recipe_postinit_callbacks = {}
    local caught_errors = 0
    local calls = 0
    local successful_calls = 0
    local fail_once = true

    local log = {
        Try = function(_, fn, ...)
            local ok, result = pcall(fn, ...)
            if not ok then
                caught_errors = caught_errors + 1
            end
            return ok, result
        end,
        Info = function() end,
        WarnOnce = function() end,
        Error = function(_, message) error(message) end,
    }

    local guard = {
        Init = function() end,
        dump = function() end,
        set_station = function()
            successful_calls = successful_calls + 1
            return true, "applied"
        end,
    }
    guard[method_name] = function()
        calls = calls + 1
        if fail_once and calls == 2 then
            fail_once = false
            error("simulated transient failure after a partial recipe pass")
        end
        successful_calls = successful_calls + 1
        return true, "applied"
    end

    package.loaded["mam/log"] = nil
    package.loaded["mam/recipe_guard"] = nil
    package.loaded["recipe"] = nil
    package.loaded["techtree"] = nil
    package.preload["mam/log"] = function() return log end
    package.preload["mam/recipe_guard"] = function() return guard end
    package.preload["recipe"] = function() return true end
    package.preload["techtree"] = function() return {} end

    GLOBAL = {
        require = require,
        Ingredient = function(prefab, amount, atlas)
            return { type = prefab, amount = amount, atlas = atlas }
        end,
        TECH = {
            NONE = {},
            SCIENCE_ONE = {},
            CRAFTSBOOK_ONE = {},
        },
        Recipe = {},
        RECIPETABS = {},
        AllRecipes = {},
        STRINGS = { NAMES = {} },
        CUSTOM_RECIPETABS = {},
    }

    AddRecipe2 = function() end
    AddRecipePostInit = function(name, fn) recipe_postinit_callbacks[name] = fn end
    AddSimPostInit = function(fn) table.insert(sim_callbacks, fn) end
    AddPrefabPostInit = function(name, fn) prefab_callbacks[name] = fn end

    dofile(module_path)
    if module_path:find("modded_recipes.lua", 1, true) then
        local deconstruct_postinit = recipe_postinit_callbacks.archive_resonator
        check(type(deconstruct_postinit) == "function", "registers Astral Detector deconstruction post-init")
        local vanilla_deconstruction = {
            is_deconstruction_recipe = true,
            ingredients = {
                { type = "moonrocknugget", amount = 1 },
                { type = "thulecite", amount = 1 },
            },
        }
        deconstruct_postinit(vanilla_deconstruction)
        check(#vanilla_deconstruction.ingredients == 2
            and vanilla_deconstruction.ingredients[1].type == "moonglass_ingot"
            and vanilla_deconstruction.ingredients[1].amount == 1
            and vanilla_deconstruction.ingredients[2].type == "thulecite"
            and vanilla_deconstruction.ingredients[2].amount == 1,
            "Astral Detector hammer refund matches half of the MAM Moonglass cost")
        local third_party_deconstruction = {
            is_deconstruction_recipe = true,
            ingredients = {
                { type = "third_party_material", amount = 2 },
                { type = "thulecite", amount = 1 },
            },
        }
        deconstruct_postinit(third_party_deconstruction)
        check(third_party_deconstruction.ingredients[1].type == "third_party_material"
            and third_party_deconstruction.ingredients[1].amount == 2,
            "preserves third-party Astral Detector deconstruction overrides")
    end
    check(#sim_callbacks == 1, module_path .. " registers one sim post-init")

    -- First pass fails after one successful recipe. MAMLog.Try catches it,
    -- then the world-prefab task is the designed retry path.
    sim_callbacks[1]()
    check(caught_errors == 1, module_path .. " catches the transient partial-pass failure")
    check(successful_calls == 1, module_path .. " applied one entry before failure")

    local world = {
        DoTaskInTime = function(self, delay, fn)
            self.task_delay = delay
            self.task = fn
        end,
    }
    assert(prefab_callbacks.world ~= nil, module_path .. " registers the world fallback")
    prefab_callbacks.world(world)
    assert(type(world.task) == "function", module_path .. " schedules fallback retry")
    world.task()

    check(successful_calls >= expected_minimum,
        module_path .. " retries and completes the remaining recipe pass")
    check(caught_errors == 1, module_path .. " does not fail again during retry")
end

run_case(
    "dst-mods/metals_and_reforged/initialise/modded_craftbook.lua",
    "regate",
    30
)
run_case(
    "dst-mods/metals_and_reforged/initialise/modded_recipes.lua",
    "apply",
    20
)

print(("PASS: %d recipe application retry contracts"):format(passed))
