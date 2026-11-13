-- Server-authoritative, material-only recovery for Metals and More Reforged.
-- Equipment, weapons, armor, tools and structures are intentionally unsupported.

local MAMDeconstruction = {}
MAMDeconstruction.BASE_RECOVERY = 0.75

local RETURNS =
{
    copper_ore = { { prefab = "copper_dust", count = 2, material = "nonmagical" } },
    copper_ingot = { { prefab = "copper_ore", count = 3, material = "nonmagical" } },
    iron_ore = { { prefab = "iron_dust", count = 2, material = "nonmagical" } },
    iron_ingot = { { prefab = "iron_ore", count = 3, material = "nonmagical" } },
    goldnugget = { { prefab = "gold_dust", count = 2, material = "nonmagical" } },
    gold_ingot = { { prefab = "goldnugget", count = 3, material = "nonmagical" } },
    bronze_ingot =
    {
        { prefab = "copper_ore", count = 3, material = "nonmagical" },
        { prefab = "iron_ore", count = 1, material = "nonmagical" },
    },
    moonglass_ingot =
    {
        { prefab = "moonglass", count = 2, material = "lunar" },
        { prefab = "moonrocknugget", count = 1, material = "lunar" },
    },
    adamantium_ingot =
    {
        { prefab = "nightmarefuel", count = 3, material = "shadow" },
        { prefab = "iron_ingot", count = 1, material = "nonmagical" },
    },
}

-- Explicit survivor profiles make character resolution predictable. Only
-- documented material specialties receive overrides; all other survivors
-- use the balanced standard rate until a justified specialty is implemented.
local CHARACTER_PROFILES =
{
    wilson = { all = 1 },
    willow = {},
    wolfgang = {},
    wendy = {},
    wx78 = {},
    wickerbottom = {},
    woodie = {},
    wes = {},
    waxwell = { shadow = 1 },
    wigfrid = {},
    webber = {},
    winona = { nonmagical = 1 },
    warly = {},
    wortox = {},
    wormwood = {},
    wurt = {},
    walter = {},
    wanda = {},
}

local function character_rate(character, material)
    local profile = CHARACTER_PROFILES[character]
    if profile ~= nil then
        return profile[material] or profile.all or MAMDeconstruction.BASE_RECOVERY
    end
    -- Unknown modded survivors get a safe fallback, not a guessed bonus.
    return MAMDeconstruction.BASE_RECOVERY
end

local function add_recovered(totals, prefab, amount, material, character, roll)
    local expected = amount * character_rate(character, material)
    local recovered = math.floor(expected)
    local fraction = expected - recovered
    if fraction > 0 and roll() < fraction then
        recovered = recovered + 1
    end
    if recovered > 0 then
        totals[prefab] = (totals[prefab] or 0) + recovered
    end
end

function MAMDeconstruction.GetReturns(prefab)
    return RETURNS[prefab]
end

function MAMDeconstruction.IsSupported(prefab)
    return RETURNS[prefab] ~= nil
end

function MAMDeconstruction.GetRecoveryRate(character, material)
    return character_rate(character, material)
end

-- roll() is injected for deterministic tests and must return a value in [0, 1).
function MAMDeconstruction.BuildPlan(prefab, character, roll)
    local entries = RETURNS[prefab]
    if entries == nil then
        return nil, "unsupported"
    end

    roll = roll or math.random
    local totals = {}
    for _, entry in ipairs(entries) do
        add_recovered(totals, entry.prefab, entry.count, entry.material, character, roll)
    end

    local result = {}
    for name, count in pairs(totals) do
        table.insert(result, { prefab = name, count = count })
    end
    table.sort(result, function(a, b) return a.prefab < b.prefab end)
    return result
end

return MAMDeconstruction
