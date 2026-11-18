local original_global_tech = TECH
local original_tuning = TUNING
local original_techtree = package.loaded["techtree"]

local TechTree = {
    AVAILABLE_TECH = { "SCIENCE" },
    BONUS_TECH = { "SCIENCE" },
    AVAILABLE_TECH_BONUS = { SCIENCE = "science_bonus" },
    AVAILABLE_TECH_TEMPBONUS = { SCIENCE = "science_tempbonus" },
    AVAILABLE_TECH_BONUS_CLASSIFIED = { SCIENCE = "sciencebonus" },
    AVAILABLE_TECH_TEMPBONUS_CLASSIFIED = { SCIENCE = "sciencetempbonus" },
    AVAILABLE_TECH_LEVEL_CLASSIFIED = { SCIENCE = "sciencelevel" },
}
function TechTree.Create(levels)
    local tree = {}
    for _, name in ipairs(TechTree.AVAILABLE_TECH) do
        tree[name] = 0
    end
    for name, value in pairs(levels or {}) do
        tree[name] = value
    end
    return tree
end

package.loaded["techtree"] = TechTree
TECH = { NONE = TechTree.Create(), SCIENCE_TWO = { SCIENCE = 2 } }
TUNING = { PROTOTYPER_TREES = {} }

local MAMTech = dofile("dst-mods/metals_and_reforged/scripts/mam/tech.lua")
local trees = MAMTech.Register()

local function count(list, value)
    local total = 0
    for _, item in ipairs(list) do
        if item == value then total = total + 1 end
    end
    return total
end

for _, name in ipairs({ "ALCHEMY", "CRAFTSBOOK", "MAM_FORGE" }) do
    assert(count(TechTree.AVAILABLE_TECH, name) == 1)
    assert(count(TechTree.BONUS_TECH, name) == 1)
    local lower = string.lower(name)
    assert(TechTree.AVAILABLE_TECH_BONUS[name] == lower .. "_bonus")
    assert(TechTree.AVAILABLE_TECH_TEMPBONUS[name] == lower .. "_tempbonus")
    assert(TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[name] == lower .. "bonus")
    assert(TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[name] == lower .. "tempbonus")
    assert(TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[name] == lower .. "level")
end

assert(TECH.ALCHEMY_ONE.ALCHEMY == 1)
assert(TECH.CRAFTSBOOK_ONE.CRAFTSBOOK == 1)
assert(TECH.MAM_FORGE_ONE.MAM_FORGE == 1)
assert(TUNING.PROTOTYPER_TREES.ALCHEMY_ONE.ALCHEMY == 1)
assert(TUNING.PROTOTYPER_TREES.CRAFTSBOOK_ONE.CRAFTSBOOK == 1)
assert(TUNING.PROTOTYPER_TREES.MAM_FORGE_ONE.MAM_FORGE == 1)
assert(trees.MAM_FORGE.MAM_FORGE == 1)

MAMTech.Register()
for _, name in ipairs({ "ALCHEMY", "CRAFTSBOOK", "MAM_FORGE" }) do
    assert(count(TechTree.AVAILABLE_TECH, name) == 1)
    assert(count(TechTree.BONUS_TECH, name) == 1)
end

TECH = original_global_tech
TUNING = original_tuning
package.loaded["techtree"] = original_techtree

io.write("MAM custom tech trees: registration, recipe tech and idempotence passed\n")
