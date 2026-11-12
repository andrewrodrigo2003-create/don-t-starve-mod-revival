package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path

local recovery = require("mam/deconstruction")
local function always_success() return 0 end
local function always_fail() return 0.99 end

local standard_bronze = assert(recovery.BuildPlan("bronze_ingot", "generic", always_fail))
assert(#standard_bronze == 1 and standard_bronze[1].prefab == "copper_ore"
    and standard_bronze[1].count == 2,
    "standard recovery should apply fractional 75 percent recovery")

local bronze = assert(recovery.BuildPlan("bronze_ingot", "winona", always_fail))
assert(#bronze == 2, "Winona should recover both non-magical bronze components")
assert(bronze[1].prefab == "copper_ore" and bronze[1].count == 3)
assert(bronze[2].prefab == "iron_ore" and bronze[2].count == 1)

local adamantium = assert(recovery.BuildPlan("adamantium_ingot", "waxwell", always_fail))
assert(#adamantium == 1 and adamantium[1].prefab == "nightmarefuel"
    and adamantium[1].count == 3,
    "Maxwell should recover shadow material fully")

local wilson = assert(recovery.BuildPlan("adamantium_ingot", "wilson", always_fail))
assert(#wilson == 2, "Wilson should recover every exact alloy component")
assert(wilson[1].prefab == "iron_ingot" and wilson[1].count == 1)
assert(wilson[2].prefab == "nightmarefuel" and wilson[2].count == 3)

local specialist = assert(recovery.BuildPlan("copper_ingot", "wilson", always_fail))
assert(specialist[1].count == 3, "Wilson should have 100 percent recovery")
local base_success = assert(recovery.BuildPlan("copper_ingot", "generic", always_success))
assert(base_success[1].count == 3, "successful fractional rolls should recover all units")

-- Every current vanilla survivor has an explicit profile, even when the
-- justified behavior is the common baseline. Modded survivors use fallback.
for _, character in ipairs({
    "wilson", "willow", "wolfgang", "wendy", "wx78", "wickerbottom",
    "woodie", "wes", "waxwell", "wigfrid", "webber", "winona",
    "warly", "wortox", "wormwood", "wurt", "walter", "wanda",
}) do
    assert(type(recovery.GetRecoveryRate(character, "nonmagical")) == "number",
        "missing character recovery profile: " .. character)
end
assert(recovery.GetRecoveryRate("winona", "nonmagical") == 1)
assert(recovery.GetRecoveryRate("waxwell", "shadow") == 1)
assert(recovery.GetRecoveryRate("wilson", "lunar") == 1)
assert(recovery.GetRecoveryRate("wx78", "nonmagical") == 0.75)
assert(recovery.GetRecoveryRate("wickerbottom", "lunar") == 0.75)
assert(recovery.GetRecoveryRate("modded_survivor", "nonmagical") == 0.75)

-- The feature is strictly material-only: no crafted equipment, weapons,
-- armor, tools or structures may be dismantled.
for _, prefab in ipairs({
    "halberd", "forginghammer", "pithpike", "blacksmith_edge",
    "goldenaxe", "armormarble", "dragonflychest", "birdcage",
}) do
    assert(not recovery.IsSupported(prefab), "equipment unexpectedly supported: " .. prefab)
    assert(recovery.BuildPlan(prefab, "wilson", always_success) == nil,
        "equipment must not produce a dismantling plan: " .. prefab)
end

assert(recovery.IsSupported("copper_ore"))
assert(recovery.IsSupported("iron_ingot"))
assert(recovery.IsSupported("bronze_ingot"))
assert(recovery.IsSupported("moonglass_ingot"))
assert(recovery.IsSupported("adamantium_ingot"))
assert(recovery.BuildPlan("unknown_metal", "wilson", always_success) == nil)

print("PASS: material-only deconstruction, survivor profile resolution and unsupported equipment")
