local TechTree = require("techtree")

local M = {}

local TECH_NAMES =
{
    "ALCHEMY",
    "CRAFTSBOOK",
    "MAM_FORGE",
}

local function add_unique(list, value)
    for _, current in ipairs(list) do
        if current == value then
            return
        end
    end
    table.insert(list, value)
end

function M.Register()
    assert(type(TECH) == "table", "MAM tech registration requires the global TECH table")
    assert(type(TUNING) == "table" and type(TUNING.PROTOTYPER_TREES) == "table",
        "MAM tech registration requires TUNING.PROTOTYPER_TREES")

    for _, name in ipairs(TECH_NAMES) do
        add_unique(TechTree.AVAILABLE_TECH, name)
        add_unique(TechTree.BONUS_TECH, name)

        local lower = string.lower(name)
        TechTree.AVAILABLE_TECH_BONUS[name] = TechTree.AVAILABLE_TECH_BONUS[name] or lower .. "_bonus"
        TechTree.AVAILABLE_TECH_TEMPBONUS[name] = TechTree.AVAILABLE_TECH_TEMPBONUS[name] or lower .. "_tempbonus"
        TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[name] = TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[name] or lower .. "bonus"
        TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[name] = TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[name] or lower .. "tempbonus"
        TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[name] = TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[name] or lower .. "level"
    end

    TUNING.PROTOTYPER_TREES.ALCHEMY_ONE = TUNING.PROTOTYPER_TREES.ALCHEMY_ONE
        or TechTree.Create({ ALCHEMY = 1 })
    TUNING.PROTOTYPER_TREES.CRAFTSBOOK_ONE = TUNING.PROTOTYPER_TREES.CRAFTSBOOK_ONE
        or TechTree.Create({ CRAFTSBOOK = 1 })
    TUNING.PROTOTYPER_TREES.MAM_FORGE_ONE = TUNING.PROTOTYPER_TREES.MAM_FORGE_ONE
        or TechTree.Create({ MAM_FORGE = 1 })

    TECH.ALCHEMY_ONE = TECH.ALCHEMY_ONE or TechTree.Create({ ALCHEMY = 1 })
    TECH.CRAFTSBOOK_ONE = TECH.CRAFTSBOOK_ONE or TechTree.Create({ CRAFTSBOOK = 1 })
    TECH.MAM_FORGE_ONE = TECH.MAM_FORGE_ONE or TechTree.Create({ MAM_FORGE = 1 })

    return {
        ALCHEMY = TECH.ALCHEMY_ONE,
        CRAFTSBOOK = TECH.CRAFTSBOOK_ONE,
        MAM_FORGE = TECH.MAM_FORGE_ONE,
    }
end

return M
