-- Server-authoritative material recovery for Metals and More Reforged.
-- Material prefabs use fixed canonical returns; crafted metal equipment uses
-- its live recipe ingredients so other mods' cost changes are preserved.

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

-- Only recipes that belong to the metal progression / War Bench are eligible.
-- Ingredients are read from AllRecipes at runtime, never copied from vanilla.
local CRAFTED_ITEMS =
{
    armor_sanity = true,
    nightsword = true,
    jagged_armor = true,
    tfwp_luxury_nox_helm_hat = true,
    halberd = true,
    scepter = true,
    forkstick = true,
    shears = true,
    donharpoon = true,
    forginghammer = true,
    pithpike = true,
    spiralspear = true,
    blacksmith_edge = true,
    forginghammerold = true,
    pithpikeold = true,
    blacksmith_edgeold = true,
    birdcage = true,
    dragonflychest = true,
    compass = true,
    razor = true,
    lightning_rod = true,
    goldenaxe = true,
    goldenpickaxe = true,
    goldenshovel = true,
    golden_farm_hoe = true,
    armormarble = true,
    armordragonfly = true,
    ruinshat = true,
    armorruins = true,
    multitool_axe_pickaxe = true,
    winterometer = true,
    rainometer = true,
    nightlight = true,
    portablecookpot_item = true,
    portableblender_item = true,
    portablespicer_item = true,
    glasscutter = true,
    archive_resonator_item = true,
    moondial = true,
    moonrockcrater = true,
    moonglassaxe = true,
}

local MATERIAL_CLASS =
{
    copper_ore = "nonmagical",
    copper_dust = "nonmagical",
    copper_ingot = "nonmagical",
    iron_ore = "nonmagical",
    iron_dust = "nonmagical",
    iron_ingot = "nonmagical",
    gold_dust = "nonmagical",
    goldnugget = "nonmagical",
    gold_ingot = "nonmagical",
    bronze_ingot = "nonmagical",
    nightmarefuel = "shadow",
    adamantium_ingot = "shadow",
    moonglass = "lunar",
    moonglass_ingot = "lunar",
    moonrocknugget = "lunar",
}

local function character_rate(character, material)
    if character == "wilson" then
        return 1
    elseif character == "winona" and material == "nonmagical" then
        return 1
    elseif character == "waxwell" and material == "shadow" then
        return 1
    end

    -- No user-defined WX-78/Wickerbottom bonus exists yet. Both use the
    -- standard rate rather than inventing a character perk.
    return MAMDeconstruction.BASE_RECOVERY
end

local function add_recovered(totals, prefab, amount, material, character, roll, durability)
    local expected = amount * character_rate(character, material) * durability
    local recovered = math.floor(expected)
    local fraction = expected - recovered
    if fraction > 0 and roll() < fraction then
        recovered = recovered + 1
    end
    if recovered > 0 then
        totals[prefab] = (totals[prefab] or 0) + recovered
    end
end

local function recipe_entries(recipe)
    if recipe == nil or recipe.no_deconstruction then
        return nil
    end
    local ingredients = recipe.ingredients
    if type(ingredients) ~= "table" or #ingredients == 0 then
        return nil
    end
    local numtogive = math.max(1, tonumber(recipe.numtogive) or 1)
    local entries = {}
    for _, ingredient in ipairs(ingredients) do
        if type(ingredient.type) == "string" and type(ingredient.amount) == "number"
            and ingredient.amount > 0 then
            table.insert(entries, {
                prefab = ingredient.type,
                count = ingredient.amount / numtogive,
                material = MATERIAL_CLASS[ingredient.type] or "other",
            })
        end
    end
    return #entries > 0 and entries or nil
end

function MAMDeconstruction.GetReturns(prefab)
    return RETURNS[prefab]
end

function MAMDeconstruction.IsSupported(prefab)
    return RETURNS[prefab] ~= nil or CRAFTED_ITEMS[prefab] == true
end

function MAMDeconstruction.GetRecoveryRate(character, material)
    return character_rate(character, material)
end

-- roll() must return a number in [0, 1). Injected for deterministic tests.
-- recipe is the live AllRecipes[prefab]; durability is the item's remaining
-- finite-use/armor percentage, clamped to [0, 1].
function MAMDeconstruction.BuildPlan(prefab, character, roll, recipe, durability)
    local entries = RETURNS[prefab]
    if entries == nil and CRAFTED_ITEMS[prefab] then
        entries = recipe_entries(recipe)
    end
    if entries == nil then
        return nil, "unsupported"
    end

    roll = roll or math.random
    durability = math.max(0, math.min(1, tonumber(durability) or 1))
    local totals = {}
    for _, entry in ipairs(entries) do
        add_recovered(totals, entry.prefab, entry.count, entry.material,
            character, roll, durability)
    end

    local result = {}
    for name, count in pairs(totals) do
        table.insert(result, { prefab = name, count = count })
    end
    table.sort(result, function(a, b) return a.prefab < b.prefab end)
    return result
end

return MAMDeconstruction
