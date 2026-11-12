-- ===========================================================================
-- Livro de receitas (craftbook): mover equipamento e utilidades vanilla para a
-- bancada propria do mod.
--
-- Antes isto eram ~36 chamadas `AddRecipe2` soltas no modmain. O problema nao e' o
-- craftbook em si -- e' que `AddRecipe2("backpack", ...)` com um nome ja existente
-- substitui o objeto Recipe inteiro, inclusive os ingredientes que OUTRO mod tenha
-- reequilibrado para aquela receita. A auditoria confirmou colisao real nas duas
-- mods que o usuario joga:
--
--   * Uncompromising Mode Beta 6.0.3.8 reescreve ingredientes de `seedpouch`
--     (init/init_recipes/recipe_changes.lua:135), `catcoonhat` (:141) e
--     `purpleamulet` (:312);
--   * "My Moar Metals" v422 registra 39 dos mesmos nomes vanilla com o proprio
--     balanceamento (scripts/recipes.lua, scripts/characters.lua).
--
-- Agora a migracao roda em `AddSimPostInit` -- depois de todos os modmain -- e o
-- recipe_guard decide, por receita, se usamos a nossa lista (receita ainda vanilla)
-- ou a lista viva de quem ja a rebalanceou, mantendo em ambos os casos o nivel de
-- tecnologia do craftbook. Ver scripts/mam/recipe_guard.lua.
--
-- As listas de ingredientes abaixo sao as do v2.9.3, transcritas sem alteracao.
-- ===========================================================================

local require = GLOBAL.require
local Ingredient = GLOBAL.Ingredient
local TECH = GLOBAL.TECH

local MAMLog = require("mam/log")
local MAMRecipeGuard = require("mam/recipe_guard")

MAMRecipeGuard.Init(AddRecipe2, AddRecipeToFilter)

local BRONZE_INGOT_ATLAS = "images/inventoryimages/bronze_ingot.xml"
local GOLD_INGOT_ATLAS = "images/inventoryimages/gold_ingot.xml"

-- A receita da propria estacao: prefab nosso, nenhum outro mod o registra.
AddRecipe2("craftbook", {Ingredient("papyrus", 2), Ingredient("charcoal", 2)}, TECH.NONE, {image = "waxwelljournal.tex"}, {"PROTOTYPERS"})

local CRAFTBOOK_RECIPES =
{
    { name = "seedpouch", ingredients = { Ingredient("slurtle_shellpieces", 2), Ingredient("cutgrass", 4), Ingredient("seeds", 2) } },
    { name = "icepack", ingredients = { Ingredient("bearger_fur", 1), Ingredient("gears", 1), Ingredient("transistor", 1) } },
    { name = "piggyback", ingredients = { Ingredient("pigskin", 4), Ingredient("silk", 6), Ingredient("rope", 2) } },
    { name = "sewing_kit", ingredients = { Ingredient("log", 1), Ingredient("silk", 8), Ingredient("houndstooth", 2) } },
    { name = "flowerhat", ingredients = { Ingredient("petals", 12) } },
    { name = "purpleamulet", ingredients = { Ingredient("goldnugget", 6), Ingredient("nightmarefuel", 4), Ingredient("purplegem", 2) } },
    { name = "amulet", ingredients = { Ingredient("goldnugget", 3), Ingredient("nightmarefuel", 2), Ingredient("redgem", 1) } },
    { name = "blueamulet", ingredients = { Ingredient("goldnugget", 3), Ingredient("bluegem", 1) } },
    { name = "umbrella", ingredients = { Ingredient("twigs", 6), Ingredient("pigskin", 1), Ingredient("silk", 2) } },
    { name = "molehat", ingredients = { Ingredient("mole", 2), Ingredient("transistor", 2), Ingredient("wormlight", 1) } },
    -- ours: bronze_ingot no lugar do goldnugget vanilla
    { name = "minerhat", ingredients = { Ingredient("strawhat", 1), Ingredient("bronze_ingot", 1, BRONZE_INGOT_ATLAS), Ingredient("fireflies", 1) } },
    { name = "backpack", ingredients = { Ingredient("cutgrass", 4), Ingredient("twigs", 4) } },
    { name = "armorslurper", ingredients = { Ingredient("slurper_pelt", 6), Ingredient("rope", 2), Ingredient("nightmarefuel", 2) } },
    { name = "icehat", ingredients = { Ingredient("transistor", 2), Ingredient("rope", 4), Ingredient("ice", 10) } },
    -- ours: exige winterhat e 2 chifres
    { name = "beefalohat", ingredients = { Ingredient("beefalowool", 8), Ingredient("horn", 2), Ingredient("winterhat", 1) } },
    { name = "earmuffshat", ingredients = { Ingredient("rabbit", 2), Ingredient("twigs", 1) } },
    -- ours: exige earmuffshat
    { name = "winterhat", ingredients = { Ingredient("beefalowool", 4), Ingredient("silk", 4), Ingredient("earmuffshat", 1) } },
    { name = "beehat", ingredients = { Ingredient("silk", 8), Ingredient("rope", 1) } },
    { name = "trunkvest_summer", ingredients = { Ingredient("trunk_summer", 1), Ingredient("silk", 8) } },
    { name = "bushhat", ingredients = { Ingredient("strawhat", 1), Ingredient("rope", 1), Ingredient("dug_berrybush", 1) } },
    { name = "catcoonhat", ingredients = { Ingredient("coontail", 3), Ingredient("silk", 4) } },
    { name = "sweatervest", ingredients = { Ingredient("houndstooth", 8), Ingredient("silk", 6) } },
    { name = "eyebrellahat", ingredients = { Ingredient("deerclops_eyeball", 1), Ingredient("twigs", 15), Ingredient("boneshard", 4) } },
    { name = "watermelonhat", ingredients = { Ingredient("watermelon", 1), Ingredient("twigs", 3) } },
    { name = "featherhat", ingredients = { Ingredient("feather_crow", 3), Ingredient("feather_robin", 2), Ingredient("tentaclespots", 2) } },
    { name = "hawaiianshirt", ingredients = { Ingredient("papyrus", 3), Ingredient("silk", 3), Ingredient("cactus_flower", 5) } },
    { name = "beargervest", ingredients = { Ingredient("bearger_fur", 1), Ingredient("sweatervest", 1), Ingredient("rope", 2) } },
    -- ours: gold_ingot no lugar do goldnugget vanilla
    { name = "cane", ingredients = { Ingredient("gold_ingot", 2, GOLD_INGOT_ATLAS), Ingredient("walrus_tusk", 1), Ingredient("twigs", 4) } },
    { name = "tophat", ingredients = { Ingredient("silk", 6) } },
    { name = "strawhat", ingredients = { Ingredient("cutgrass", 12) } },
    { name = "reflectivevest", ingredients = { Ingredient("rope", 1), Ingredient("feather_robin", 3), Ingredient("pigskin", 2) } },
    { name = "rainhat", ingredients = { Ingredient("mole", 2), Ingredient("strawhat", 1), Ingredient("boneshard", 1) } },
    { name = "raincoat", ingredients = { Ingredient("tentaclespots", 2), Ingredient("rope", 2), Ingredient("boneshard", 2) } },
    { name = "trunkvest_winter", ingredients = { Ingredient("trunk_winter", 1), Ingredient("silk", 8), Ingredient("beefalowool", 2) } },
    -- ours: costura um bernie inativo a partir de cabelo de barba + lula
    { name = "bernie_inactive", ingredients = { Ingredient("beardhair", 3), Ingredient("beefalowool", 6), Ingredient("sewing_kit", 1) } },
}

-- goggleshat e deserthat estavam comentadas no original (TECH.LOST / "LOST") e
-- continuam desligadas: sem motivo documentado para reativa-las.

local has_been_applied = false

local function apply_craftbook(where)
    if has_been_applied then
        return
    end

    local moved, kept = 0, 0
    for _, entry in ipairs(CRAFTBOOK_RECIPES) do
        local applied, reason = MAMRecipeGuard.regate(
            entry.name, entry.ingredients, TECH.CRAFTSBOOK_ONE, { nounlock = true })
        if applied then
            moved = moved + 1
            if reason == "kept-others-ingredients" then
                kept = kept + 1
            end
        end
    end

    -- Only mark the pass complete after every entry has been processed.
    -- MAMLog.Try catches failures; leaving this false lets the world-task fallback retry.
    has_been_applied = true

    MAMLog.Info("craftbook (%s): %d/%d receitas migradas, %d preservando balanceamento de outro mod",
        where, moved, #CRAFTBOOK_RECIPES, kept)
end

AddSimPostInit(function()
    MAMLog.Try("modded_craftbook.simpostinit", apply_craftbook, "sim post-init")
end)

-- Mesmo rede de seguranca de modded_recipes.lua: a primeira task do world roda
-- depois de qualquer sim post-init, e a flag impede aplicacao dupla.
for _, world_prefab_name in ipairs({ "world", "forest" }) do
    AddPrefabPostInit(world_prefab_name, function(inst)
        inst:DoTaskInTime(0, function()
            apply_craftbook("primeira task do world")
        end)
    end)
end
