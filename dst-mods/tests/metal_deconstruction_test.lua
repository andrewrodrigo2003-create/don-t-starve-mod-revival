package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path

local recovery = require("mam/deconstruction")

local function always_success()
    return 0
end

local function always_fail()
    return 0.99
end

local bronze = assert(recovery.BuildPlan("bronze_ingot", "winona", always_fail))
assert(#bronze == 2, "Winona should recover both bronze components")
assert(bronze[1].prefab == "copper_ore" and bronze[1].count == 3)
assert(bronze[2].prefab == "iron_ore" and bronze[2].count == 1)

local adamantium = assert(recovery.BuildPlan("adamantium_ingot", "waxwell", always_fail))
assert(#adamantium == 1, "Maxwell should recover only the shadow component at 100%")
assert(adamantium[1].prefab == "nightmarefuel" and adamantium[1].count == 3)

local wilson = assert(recovery.BuildPlan("adamantium_ingot", "wilson", always_fail))
assert(#wilson == 2, "Wilson should recover every component")
assert(wilson[1].prefab == "iron_ingot" and wilson[1].count == 1)
assert(wilson[2].prefab == "nightmarefuel" and wilson[2].count == 3)

local specialist = assert(recovery.BuildPlan("copper_ingot", "wilson", always_fail))
assert(specialist[1].count == 3, "Wilson should have 100% recovery")

local base_success = assert(recovery.BuildPlan("copper_ingot", "generic", always_success))
assert(base_success[1].count == 3, "successful 75% rolls should recover each component")
local none = assert(recovery.BuildPlan("copper_ingot", "generic", always_fail))
assert(#none == 0, "failed 75% rolls should not create material")

assert(recovery.GetRecoveryRate("winona", "nonmagical") == 1)
assert(recovery.GetRecoveryRate("waxwell", "shadow") == 1)
assert(recovery.GetRecoveryRate("wilson", "lunar") == 1)
assert(recovery.GetRecoveryRate("wx78", "nonmagical") == 0.75)
assert(recovery.GetRecoveryRate("wickerbottom", "lunar") == 0.75)
assert(recovery.BuildPlan("unknown_metal", "wilson", always_success) == nil)

print("PASS: material deconstruction rates, alloys, specialists and unsupported inputs")
