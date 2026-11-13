-- Verifies the dedicated chest is no longer offered to new worlds,
-- while the prefab/widget remain registered for old saves.
local function read(path)
    local file = assert(io.open(path, "r"), "missing file: " .. path)
    local value = file:read("*a")
    file:close()
    return value
end

local modinfo = read("dst-mods/metals_and_reforged/modinfo.lua")
local modmain = read("dst-mods/metals_and_reforged/modmain.lua")

assert(not modinfo:find('name = "mam_metalschest"', 1, true),
    "dedicated chest config option must be removed")
assert(not modmain:find('AddRecipe2("metal_storage_chest"', 1, true),
    "dedicated chest recipe must not be registered")
assert(not modmain:find('MAMConfig.on("mam_metalschest")', 1, true),
    "modmain must not depend on the retired config option")

assert(modmain:find('"metal_storage_chest"', 1, true),
    "legacy prefab must remain registered for existing saves")
assert(modmain:find("params.metal_storage_chest = makeChest()", 1, true),
    "legacy container widget must remain registered")
assert(modmain:find("params.metal_storage_chest.itemtestfn", 1, true),
    "legacy item filter must remain intact")

print("PASS: dedicated chest recipe/config retired; legacy save support preserved")
