GLOBAL.require("recipe")
TechTree = GLOBAL.require("techtree")
TECH = GLOBAL.TECH
Recipe = GLOBAL.Recipe
RECIPETABS = GLOBAL.RECIPETABS
Ingredient = GLOBAL.Ingredient
AllRecipes = GLOBAL.AllRecipes
STRINGS = GLOBAL.STRINGS
CUSTOM_RECIPETABS = GLOBAL.CUSTOM_RECIPETABS

local require = GLOBAL.require
local MAMLog = require("mam/log")
local MAMRecipeGuard = require("mam/recipe_guard")

-- AddRecipe2 so existe no ambiente do modmain (modutil.lua:732 a poe em env, nao em
-- GLOBAL), entao o guarda precisa que alguem a injete para o caminho de migracao de
-- bancada. Idempotente: modded_craftbook.lua faz o mesmo.
MAMRecipeGuard.Init(AddRecipe2, AddRecipeToFilter)

local IRON_ORE_ATLAS = "images/inventoryimages/iron_ore.xml"
local IRON_INGOT_ATLAS = "images/inventoryimages/iron_ingot.xml"
local COPPER_INGOT_ATLAS = "images/inventoryimages/copper_ingot.xml"
local GOLD_INGOT_ATLAS = "images/inventoryimages/gold_ingot.xml"
local BRONZE_INGOT_ATLAS = "images/inventoryimages/bronze_ingot.xml"
local MOONGLASS_INGOT_ATLAS = "images/inventoryimages/moonglass_ingot.xml"

-- ===========================================================================
-- 1) RECEITAS NOSSAS (aditivas, em tempo de carga)
--
-- Nenhum outro mod registra esses nomes: verificado contra Uncompromising Mode
-- Beta 6.0.3.8 (nenhuma ocorrencia de `metal_smelter` nos 1465 .lua do mod) e
-- contra "My Moar Metals" v422, que usa `ore_iron`/`rock_iron` -- ids diferentes
-- dos nossos `iron_ore`/`ironrock`. AddRecipe2 precisa rodar antes de o mundo
-- existir, para a sincronizacao de receitas em multiplayer funcionar.
-- ===========================================================================

AddRecipe2("metal_smelter", { Ingredient("iron_ore", 4, IRON_ORE_ATLAS), Ingredient("cutstone", 2) }, TECH.SCIENCE_ONE, {placer = "metal_smelter_placer", atlas="images/inventoryimages/metal_smelter.xml", image="metal_smelter.tex"}, {"STRUCTURES"})

AddRecipe2("marbleseed", { Ingredient("iron_ore", 1, IRON_ORE_ATLAS), Ingredient("marble", 1)}, TECH.SCIENCE_ONE, {atlas="images/inventoryimages/marbleseed.xml", image="marbleseed.tex"}, {"REFINE"})

-- ===========================================================================
-- 2) REESCRITAS DE RECEITAS VANILLA (protegidas e adiadas)
--
-- No v2.9.3 cada linha abaixo era `AllRecipes["x"].ingredients = {...}` executada
-- na carga do mod. Dois defeitos:
--
--   * sem teste de nil: se outro mod remove a receita, a carga crasha antes de
--     chegar ao jogo;
--   * sem teste de autoria: o mod que carrega por ultimo sobrescreve em silencio
--     o balanceamento do outro. Isso nao e' hipotese -- o UM Beta escreve
--     `AllRecipes["glasscutter"].ingredients` em
--     init/init_recipes/recipe_changes.lua:80-93 (quando `celestialitems_revert`
--     esta ligado), exatamente o campo que tocamos em `glasscutter`/`moonglassaxe`.
--
-- Agora as reescritas rodam em `AddSimPostInit` -- depois de TODOS os modmain
-- (UM Beta, Moar Metals, os nossos) terem escrito em AllRecipes -- e so sao
-- aplicadas quando a receita ainda e' identica ao vanilla (baseline transcrita em
-- scripts/mam/recipe_guard.lua). Quando a gente cede, o motivo fica no log.
--
-- Os VALORES nao mudaram: as listas de ingredientes sao as do v2.9.3, transcritas
-- uma a uma. O comentario acima de cada entrada e' a assinatura vanilla dela.
-- ===========================================================================

local OVERRIDES =
{
    -- --- A metalurgia passa a ser caminho obrigatorimo da tecnologia ---
    -- vanilla: goldnugget 1, log 4, rocks 4
    { name = "researchlab", ingredients = {
        Ingredient("iron_ore", 4, IRON_ORE_ATLAS), Ingredient("log", 4), Ingredient("rocks", 4) } },
    -- vanilla: boards 4, cutstone 2, transistor 2
    { name = "researchlab2", ingredients = {
        Ingredient("boards", 4), Ingredient("iron_ingot", 2, IRON_INGOT_ATLAS), Ingredient("transistor", 2) } },

    -- --- Bronze, ouro e ferro fundidos no dia a dia ---
    -- vanilla: papyrus 2, goldnugget 6, seeds 2
    { name = "birdcage", ingredients = {
        Ingredient("papyrus", 2), Ingredient("bronze_ingot", 1, BRONZE_INGOT_ATLAS), Ingredient("seeds", 2) } },
    -- vanilla: dragon_scales 1, boards 4, goldnugget 10
    { name = "dragonflychest", ingredients = {
        Ingredient("dragon_scales", 1), Ingredient("boards", 4), Ingredient("gold_ingot", 2, GOLD_INGOT_ATLAS) } },
    -- vanilla: goldnugget 1, flint 1
    { name = "compass", ingredients = {
        Ingredient("iron_ore", 1, IRON_ORE_ATLAS), Ingredient("flint", 1) } },
    -- vanilla: twigs 2, flint 2
    { name = "razor", ingredients = {
        Ingredient("twigs", 2), Ingredient("iron_ingot", 1, IRON_INGOT_ATLAS) } },
    -- vanilla: goldnugget 2, cutstone 1
    { name = "transistor", ingredients = {
        Ingredient("cutstone", 1), Ingredient("copper_ingot", 1, COPPER_INGOT_ATLAS) } },
    -- vanilla: goldnugget 4, cutstone 1
    { name = "lightning_rod", ingredients = {
        Ingredient("gold_ingot", 1, GOLD_INGOT_ATLAS), Ingredient("cutstone", 1) } },

    -- --- Ferramentas de ouro: nugget vira lingote fundido ---
    -- vanilla (as quatro): twigs 4, goldnugget 2
    { name = "goldenaxe", ingredients = {
        Ingredient("twigs", 4), Ingredient("gold_ingot", 1, GOLD_INGOT_ATLAS) } },
    { name = "goldenpickaxe", ingredients = {
        Ingredient("twigs", 4), Ingredient("gold_ingot", 1, GOLD_INGOT_ATLAS) } },
    { name = "goldenshovel", ingredients = {
        Ingredient("twigs", 4), Ingredient("gold_ingot", 1, GOLD_INGOT_ATLAS) } },
    { name = "golden_farm_hoe", ingredients = {
        Ingredient("twigs", 4), Ingredient("gold_ingot", 1, GOLD_INGOT_ATLAS) } },

    -- --- Marmore e cozinha portatil ---
    -- vanilla: marble 6, rope 2
    { name = "armormarble", ingredients = {
        Ingredient("marble", 12), Ingredient("rope", 4), Ingredient("iron_ingot", 1, IRON_INGOT_ATLAS) } },
    -- vanilla: goldnugget 2, charcoal 6, twigs 6
    { name = "portablecookpot_item", ingredients = {
        Ingredient("iron_ore", 3, IRON_ORE_ATLAS), Ingredient("charcoal", 6), Ingredient("twigs", 6) } },
    -- vanilla: goldnugget 2, transistor 2, twigs 4
    { name = "portableblender_item", ingredients = {
        Ingredient("iron_ore", 3, IRON_ORE_ATLAS), Ingredient("transistor", 2), Ingredient("twigs", 4) } },
    -- vanilla: goldnugget 2, cutstone 3, twigs 6
    { name = "portablespicer_item", ingredients = {
        Ingredient("iron_ore", 3, IRON_ORE_ATLAS), Ingredient("cutstone", 3), Ingredient("twigs", 6) } },

    -- --- Vidro lunar. O UM Beta escreve nos mesmos campos aqui, entao o guarda
    --     e' particularmente importante nestas cinco. ---
    -- vanilla: log 1, moonglass 5
    { name = "glasscutter", ingredients = {
        Ingredient("boards", 1), Ingredient("moonglass_ingot", 1, MOONGLASS_INGOT_ATLAS) } },
    -- vanilla: moonrocknugget 1, thulecite 1
    { name = "archive_resonator_item", ingredients = {
        Ingredient("thulecite", 1), Ingredient("moonglass_ingot", 2, MOONGLASS_INGOT_ATLAS) } },
    -- vanilla: bluemooneye 1, moonrocknugget 2, ice 2
    { name = "moondial", ingredients = {
        Ingredient("bluemooneye", 1), Ingredient("moonglass_ingot", 1, MOONGLASS_INGOT_ATLAS), Ingredient("marble", 5) } },
    -- vanilla: moonrocknugget 3
    { name = "moonrockcrater", ingredients = {
        Ingredient("moonglass_ingot", 1, MOONGLASS_INGOT_ATLAS), Ingredient("moonrocknugget", 2), Ingredient("marble", 1) } },
    -- vanilla: twigs 2, moonglass 3
    { name = "moonglassaxe", ingredients = {
        Ingredient("moonglass_ingot", 1, MOONGLASS_INGOT_ATLAS), Ingredient("twigs", 2), Ingredient("marble", 1) } },
}

-- O autor original deixou comentado (v2.9.3, linhas 65-87): winterometer,
-- rainometer, onemanband, nightlight, footballhat, armordragonfly, ruinshat,
-- armorruins, multitool_axe_pickaxe, goggleshat, deserthat. Nada disso estava
-- ativo no original, entao nada disso foi ativado aqui.

local has_been_applied = false

local function apply_vanilla_overrides(where, force)
    if has_been_applied and not force then
        return 0, 0, #OVERRIDES
    end

    local applied, pending = 0, 0
    local total = #OVERRIDES
    for _, override in ipairs(OVERRIDES) do
        local changed, reason = MAMRecipeGuard.apply(override.name, override.ingredients)
        if changed then
            applied = applied + 1
        elseif reason == "missing" then
            pending = pending + 1
        end
    end

    -- These recipes are intentionally moved by changing only their live tech
    -- requirement and filter. Their ingredient tables and metadata stay intact.
    local station_recipes =
    {
        "birdcage", "dragonflychest", "compass", "razor", "lightning_rod",
        "goldenaxe", "goldenpickaxe", "goldenshovel", "golden_farm_hoe",
        "armormarble", "armordragonfly", "ruinshat", "armorruins",
        "multitool_axe_pickaxe", "winterometer", "rainometer", "nightlight",
        "portablecookpot_item", "portableblender_item",
        "portablespicer_item", "glasscutter", "archive_resonator_item",
        "moondial", "moonrockcrater", "moonglassaxe",
    }
    local station_moved = 0
    for _, name in ipairs(station_recipes) do
        local moved, reason = MAMRecipeGuard.set_station(name, TECH.ALCHEMY_ONE, "CRAFTING_STATION")
        if moved then
            station_moved = station_moved + 1
        elseif reason == "missing" or reason == "filter-api-unavailable" or reason == "invalid-tech" then
            pending = pending + 1
        end
    end

    has_been_applied = pending == 0
    MAMLog.Info("reescritas de receitas vanilla (%s): %d/%d; bancadas metalurgicas: %d/%d; pendentes: %d",
        where, applied, total, station_moved, #station_recipes, pending)
    MAMRecipeGuard.dump()

    return pending, applied, total
end

-- Roda no servidor E no cliente, depois de todos os modmain: e' o ponto em que a
-- pergunta "outro mod mudou esta receita?" pode ser respondida com o estado final.
AddSimPostInit(function()
    MAMLog.Try("modded_recipes.simpostinit", apply_vanilla_overrides, "sim post-init")
end)

-- Rede de seguranca: mods que inspecionam AllRecipes dentro do proprio sim
-- post-init podem rodar depois do nosso. A primeira task do world e'
-- estritamente mais tarde que qualquer sim post-init, e a flag acima impede
-- aplicacao dupla.
--
-- Os dois nomes, sem teste em STRINGS: em Don't Starve Together o prefab e'
-- "world", mas o codigo legado do mod escolhia entre "world"/"forest" olhando
-- STRINGS.NAMES.MIGRATION_PORTAL -- e STRINGS ainda pode estar incompleto em
-- tempo de carga de mod, o que silenciosamente registraria o fallback no nome
-- errado. Registrar os dois custa uma tabela vazia e funciona em qualquer verso.
local function retry_world_recipe_pass(inst, attempt)
    inst:DoTaskInTime(0.5, function()
        local ok, pending = MAMLog.Try("modded_recipes.world_retry",
            apply_vanilla_overrides, "primeira task do world", true)
        if ok and pending ~= nil and pending > 0 and attempt < 3 then
            retry_world_recipe_pass(inst, attempt + 1)
        end
    end)
end

for _, world_prefab_name in ipairs({ "world", "forest" }) do
    AddPrefabPostInit(world_prefab_name, function(inst)
        retry_world_recipe_pass(inst, 1)
    end)
end
