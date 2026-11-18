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

-- This inventory is intentionally broader than the reversible allowlist. Every
-- MAM-owned material prefab must have an explicit provenance disposition so new
-- materials cannot silently disappear from deconstruction review.
local MATERIAL_AUDIT =
{
    copper_ore = { status = "recoverable", reason = "registered copper smelting material" },
    copper_ingot = { status = "recoverable", reason = "registered copper smelting product" },
    iron_ore = { status = "recoverable", reason = "registered iron smelting material" },
    iron_ingot = { status = "recoverable", reason = "registered iron smelting product" },
    goldnugget = { status = "recoverable", reason = "registered gold smelting material" },
    gold_ingot = { status = "recoverable", reason = "registered gold smelting product" },
    bronze_ingot = { status = "recoverable", reason = "registered alloy with explicit copper and iron costs" },
    moonglass_ingot = { status = "recoverable", reason = "registered lunar smelting product with explicit moon input" },
    adamantium_ingot = { status = "recoverable", reason = "registered alloy with explicit shadow and iron inputs" },

    copper_dust = { status = "raw_input", reason = "base mineral input; no safe lower MAM conversion" },
    iron_dust = { status = "raw_input", reason = "base mineral input; no safe lower MAM conversion" },
    gold_dust = { status = "raw_input", reason = "base mineral input; no safe lower MAM conversion" },
    junk_dust = { status = "mixed_byproduct", reason = "generic output from mixed metal loads; source cannot be reconstructed" },

    redgem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    bluegem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    yellowgem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    greengem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    orangegem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    purplegem_shard = { status = "raw_gem_material", reason = "loot material; no MAM shard-to-gem recipe" },
    sharkscale = { status = "raw_creature_material", reason = "harvested material; no MAM processing recipe to reverse" },
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

-- The War Bench adds its replicated "prototyper" tag before SetPristine,
-- but its server-only component is created only after the client early return.
-- Client action discovery must therefore use the networked tag; the server
-- action handler additionally requires the authoritative component.
function MAMDeconstruction.HasWarWorkbench(entities, ismastersim)
    for _, entity in ipairs(entities or {}) do
        if entity ~= nil and entity.prefab == "warworkbench"
            and type(entity.HasTag) == "function"
            and entity:HasTag("prototyper") then
            if not ismastersim then
                return true
            end
            if entity.components ~= nil and entity.components.prototyper ~= nil then
                return true
            end
        end
    end
    return false
end

function MAMDeconstruction.GetMaterialAudit(prefab)
    local entry = MATERIAL_AUDIT[prefab]
    if entry == nil then return nil end
    return entry.status, entry.reason
end

function MAMDeconstruction.GetMaterialAuditPrefabs()
    local result = {}
    for prefab in pairs(MATERIAL_AUDIT) do
        table.insert(result, prefab)
    end
    table.sort(result)
    return result
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
