-- Server-authoritative material recovery for Metals and More Reforged.
-- The smelter remains the only route upward; this module only returns canonical
-- lower-stage components and never edits the smelting recipe/cost tables.

local MAMDeconstruction = {}

MAMDeconstruction.BASE_RECOVERY = 0.75

local RETURNS =
{
    copper_ore = {
        { prefab = "copper_dust", count = 2, material = "nonmagical" },
    },
    copper_ingot = {
        { prefab = "copper_ore", count = 3, material = "nonmagical" },
    },
    iron_ore = {
        { prefab = "iron_dust", count = 2, material = "nonmagical" },
    },
    iron_ingot = {
        { prefab = "iron_ore", count = 3, material = "nonmagical" },
    },
    goldnugget = {
        { prefab = "gold_dust", count = 2, material = "nonmagical" },
    },
    gold_ingot = {
        { prefab = "goldnugget", count = 3, material = "nonmagical" },
    },
    bronze_ingot = {
        { prefab = "copper_ore", count = 3, material = "nonmagical" },
        { prefab = "iron_ore", count = 1, material = "nonmagical" },
    },
    moonglass_ingot = {
        { prefab = "moonglass", count = 2, material = "lunar" },
        { prefab = "moonrocknugget", count = 1, material = "lunar" },
    },
    adamantium_ingot = {
        { prefab = "nightmarefuel", count = 3, material = "shadow" },
        { prefab = "iron_ingot", count = 1, material = "nonmagical" },
    },
}

local function character_rate(character, material)
    if character == "wilson" then
        return 1
    elseif character == "winona" and material == "nonmagical" then
        return 1
    elseif character == "waxwell" and material == "shadow" then
        return 1
    end

    -- WX-78 and Wickerbottom stay at the common rate until a character-specific
    -- specialty is supported by a concrete ability/lore mechanic.
    return MAMDeconstruction.BASE_RECOVERY
end

function MAMDeconstruction.GetReturns(prefab)
    return RETURNS[prefab]
end

function MAMDeconstruction.GetRecoveryRate(character, material)
    return character_rate(character, material)
end

-- roll() must return a number in [0, 1). Injected for deterministic tests.
function MAMDeconstruction.BuildPlan(prefab, character, roll)
    local recipe = RETURNS[prefab]
    if recipe == nil then
        return nil, "unsupported"
    end

    roll = roll or math.random
    local totals = {}
    for _, entry in ipairs(recipe) do
        local rate = character_rate(character, entry.material)
        local recovered = 0
        for _ = 1, entry.count do
            if rate >= 1 or roll() < rate then
                recovered = recovered + 1
            end
        end
        if recovered > 0 then
            totals[entry.prefab] = (totals[entry.prefab] or 0) + recovered
        end
    end

    local result = {}
    for name, count in pairs(totals) do
        table.insert(result, { prefab = name, count = count })
    end
    table.sort(result, function(a, b) return a.prefab < b.prefab end)
    return result
end

return MAMDeconstruction
