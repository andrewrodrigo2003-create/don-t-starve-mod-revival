-- Verifies the dedicated metal storage chest remains craftable and optional.
-- The prefab/widget are always registered for old saves; the recipe follows config.
local function read(path)
    local file = assert(io.open(path, "r"), "missing file: " .. path)
    local value = file:read("*a")
    file:close()
    return value
end

local modinfo = read("dst-mods/metals_and_reforged/modinfo.lua")
local modmain = read("dst-mods/metals_and_reforged/modmain.lua")

assert(modinfo:find('name = "mam_metalschest"', 1, true),
    "metal chest config option must be present")
assert(modinfo:find('label = "Metal storage chest"', 1, true),
    "metal chest option label must be present")
assert(modinfo:find("default = 1", 1, true),
    "metal chest should be enabled by default")
assert(modmain:find('if MAMConfig.on("mam_metalschest") then', 1, true),
    "metal chest recipe must follow the config option")
assert(modmain:find('AddRecipe2("metal_storage_chest"', 1, true),
    "metal chest recipe must be registered")
assert(modmain:find('Ingredient("iron_ingot", 3', 1, true),
    "metal chest iron cost missing")
assert(modmain:find('Ingredient("cutstone", 2)', 1, true),
    "metal chest cutstone cost missing")
assert(modmain:find('Ingredient("gears", 1)', 1, true),
    "metal chest gear cost missing")

assert(modmain:find('"metal_storage_chest"', 1, true),
    "metal chest prefab must remain registered")
assert(modmain:find("params.metal_storage_chest = makeChest()", 1, true),
    "metal chest container widget must remain registered")
assert(modmain:find("params.metal_storage_chest.itemtestfn", 1, true),
    "metal chest item filter must remain intact")

print("PASS: metal chest config, recipe, prefab, widget and filter are wired")
