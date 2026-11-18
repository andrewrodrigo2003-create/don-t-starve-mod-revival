local root = "dst-mods/metals_and_reforged/"
local config = dofile(root .. "scripts/mam/config.lua")
local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local main = read(root .. "modmain.lua")
local start = assert(main:find('AddPrototyperDef("warworkbench"', 1, true))
local finish = assert(main:find('modimport("scripts/tot_ui.lua")', start, true))
assert(main:find('modimport("initialise/modded_strings.lua")', 1, true) < start)
local station_registration = main:sub(start, finish - 1)
local expected = {
    WARWORKBENCH = { "Bancada de Guerra", "War Bench" },
    CRAFTBOOK = { "Livro de Projetos", "Craftbook" },
    MARBLE_CHEST = { "Baú de Mármore", "Marble Chest" },
    COLD_SAFE = { "Cofre Refrigerado", "Cold Storage" },
    METAL_STORAGE_CHEST = { "Baú de Metais", "Metal Storage Chest" },
}
local action_text = {
    WARWORKBENCH = { "Fabricar na", "Craft at" },
    CRAFTBOOK = { "Consultar", "Read" },
}
local baseline = {
    warworkbench = { tech = "SCIENCE_TWO", ingredients = { { "cutstone", 5 }, { "iron_ingot", 3 }, { "charcoal", 5 } } },
    marble_chest = { tech = "ALCHEMY_ONE", ingredients = { { "marble", 5 }, { "gold_ingot", 2 }, { "cutstone", 3 } } },
    cold_safe = { tech = "ALCHEMY_ONE", ingredients = { { "gears", 1 }, { "iron_ingot", 3 }, { "bluegem", 1 } } },
}
local native_actions, native_strfn
if arg[1] then
    native_actions = assert(read(arg[1] .. "/strings.lua"):match("OPEN_CRAFTING%s*=%s*(%b{})"))
    native_strfn = assert(read(arg[1] .. "/actions.lua"):match("(ACTIONS%.OPEN_CRAFTING%.strfn = function%(act%).-\nend)"))
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. ": " .. tostring(reason))
    end
end

local snapshots = {}
for _, locale in ipairs({ "ptbr", "en", "missing", "invalid" }) do
    for _, enabled in ipairs({ 0, 1 }) do
        test(locale .. ", independent features " .. enabled, function()
            config.Init(function(key)
                if key == "mam_language" then
                    if locale == "missing" then return nil end
                    return locale
                end
                if key == "mam_axe_crafting" or key == "mam_chisel_crafting"
                    or key == "mam_recipe_overrides" or key == "mam_third_party_recipe_integration" then
                    return enabled
                end
            end)
            local column = locale == "en" and 2 or 1
            local actions = native_actions and assert(loadstring("return " .. native_actions))()
                or { GENERIC = "Research at", READ = "Read", FORGE = "Forge at" }
            actions.THIRD_PARTY = "External station action"
            local untouched_actions = {}
            for key, text in pairs(actions) do untouched_actions[key] = text end
            local generic = arg[1] and assert(loadfile(arg[1] .. "/speech_wilson.lua"))()
                or { DESCRIBE = {}, ACTIONFAIL = { BUILD = {} } }
            local describe, build = generic.DESCRIBE, generic.ACTIONFAIL.BUILD
            describe.THIRD_PARTY = "External inspection"
            local strings = {
                NAMES = { THIRD_PARTY = "External item" },
                RECIPE_DESC = { THIRD_PARTY = "External recipe" },
                CHARACTERS = { GENERIC = generic, WENDY = { DESCRIBE = { THIRD_PARTY = "External Wendy" } } },
                ACTIONS = { OPEN_CRAFTING = actions },
            }
            local names, recipes = strings.NAMES, strings.RECIPE_DESC
            local defs, registered = {}, {}
            local env = setmetatable({
                GLOBAL = { STRINGS = strings, require = function(name)
                    assert(name == "mam/config")
                    return config
                end },
                STRINGS = strings,
                TECH = { SCIENCE_TWO = {}, ALCHEMY_ONE = {} },
                Ingredient = function(name, amount, atlas) return { type = name, amount = amount, atlas = atlas } end,
                AddPrototyperDef = function(name, def) defs[name] = def end,
                AddRecipe2 = function(name, ingredients, tech, options, filters)
                    registered[name] = { ingredients = ingredients, tech = tech, options = options, filters = filters }
                end,
            }, { __index = _G })
            local function load_strings()
                setfenv(assert(loadfile(root .. "initialise/modded_strings.lua")), env)()
            end
            load_strings()
            load_strings()
            setfenv(assert(loadstring(station_registration)), env)()
            -- Recipe declarations live earlier in modmain.lua; execute only the three
            -- one-line registrations under test instead of expecting them in the station block.
            for line in main:gmatch("[^\n]+") do
                local name = line:match('AddRecipe2%("([^"]+)"')
                if baseline[name] ~= nil then
                    setfenv(assert(loadstring(line)), env)()
                end
            end
            -- The reference book registration is multiline and intentionally has no prototyper.
            local book_start = assert(main:find('AddRecipe2("metallurgy_reference_book"', 1, true))
            local book_end_marker = '}, TECH.ALCHEMY_ONE, { image = "cookbook.tex" }, { "CRAFTING_STATION" })'
            local book_end = assert(main:find(book_end_marker, book_start, true))
            local book_source = main:sub(book_start, book_end + #book_end_marker - 1)
            setfenv(assert(loadstring(book_source)), env)()
            assert(strings.NAMES == names and strings.RECIPE_DESC == recipes)
            assert(generic.DESCRIBE == describe and generic.ACTIONFAIL.BUILD == build)
            assert(strings.ACTIONS.OPEN_CRAFTING == actions)
            assert(names.THIRD_PARTY == "External item" and recipes.THIRD_PARTY == "External recipe")
            assert(describe.THIRD_PARTY == "External inspection")
            assert(strings.CHARACTERS.WENDY.DESCRIBE.THIRD_PARTY == "External Wendy")
            for key, text in pairs(untouched_actions) do assert(actions[key] == text, key .. " action overwritten") end
            snapshots[locale] = {}
            for key, values in pairs(expected) do
                assert(names[key] == values[column], key .. " name not localized")
                assert(type(recipes[key]) == "string" and #recipes[key] > 0, key .. " recipe text missing")
                assert(type(describe[key]) == "string" and #describe[key] > 0, key .. " inspection missing")
                snapshots[locale][key] = { recipe = recipes[key], describe = describe[key] }
            end
            assert(names.CRAFTBOOK ~= names.METALLURGY_REFERENCE_BOOK)
            for prefab, key in pairs({ warworkbench = "WARWORKBENCH", craftbook = "CRAFTBOOK" }) do
                assert(defs[prefab].filter_text == names[key], prefab .. " filter not localized")
                assert(defs[prefab].action_str == key and actions[key] == action_text[key][column])
                assert(defs[prefab].is_crafting_station == true)
            end
            if native_strfn then
                local native_env = { ACTIONS = { OPEN_CRAFTING = {} }, PROTOTYPER_DEFS = defs }
                setfenv(assert(loadstring(native_strfn)), native_env)()
                for prefab, key in pairs({ warworkbench = "WARWORKBENCH", craftbook = "CRAFTBOOK" }) do
                    assert(native_env.ACTIONS.OPEN_CRAFTING.strfn({ target = { prefab = prefab } }) == key)
                end
                assert(native_env.ACTIONS.OPEN_CRAFTING.strfn({}) == nil)
                assert(native_env.ACTIONS.OPEN_CRAFTING.strfn({ target = { prefab = "unregistered" } }) == nil)
            end
            for prefab, recipe in pairs(baseline) do
                local current = assert(registered[prefab])
                assert(current.tech == env.TECH[recipe.tech], prefab .. " station changed")
                assert(#current.ingredients == #recipe.ingredients, prefab .. " ingredient count changed")
                for i, ingredient in ipairs(recipe.ingredients) do
                    assert(current.ingredients[i].type == ingredient[1] and current.ingredients[i].amount == ingredient[2],
                        prefab .. " cost changed")
                end
            end
            assert(registered.metal_storage_chest == nil and registered.craftbook == nil)
            assert(registered.metallurgy_reference_book ~= nil and defs.metallurgy_reference_book == nil)
        end)
    end
end

test("both locales have distinct descriptions and safe defaults", function()
    for key in pairs(expected) do
        for _, field in ipairs({ "recipe", "describe" }) do
            assert(snapshots.ptbr[key][field] ~= snapshots.en[key][field], key .. " untranslated " .. field)
            assert(snapshots.missing[key][field] == snapshots.ptbr[key][field])
            assert(snapshots.invalid[key][field] == snapshots.ptbr[key][field])
        end
    end
end)

print(string.format("Station/storage localization (%s): %d passed / %d failed",
    native_actions and "installed DST action sources, stub registration" or "stubs", passed, failed))
assert(failed == 0, "station/storage localization regressions")
