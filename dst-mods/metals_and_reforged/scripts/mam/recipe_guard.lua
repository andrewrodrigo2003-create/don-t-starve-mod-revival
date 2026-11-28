-- Guardas de reescrita de receitas vanilla.
--
-- POR QUE ISTO EXISTE
-- Metals and More reescrevia `AllRecipes["..."].ingredients` diretamente, na carga do
-- mod, para amarrar a metalurgia ao progresso vanilla. Isso tem dois problemas que o
-- briefing coloca como prioridade maxima ("evitar sobrescrever a funcionalidade de
-- outros mods"):
--
--   1. Se o recipe sumiu (outro mod o removeu), o index devolve nil e o mod crasha na
--      carga -- nem chega ao jogo.
--   2. Se outro mod reequilibrou o mesmo recipe, o ultimo mod carregado vence em
--      silencio e o trabalho do outro desaparece. Confirmado novamente contra
--      Uncompromising Mode Public Beta 6.0.3.9 (branch `utw-beta`):
--      `init/init_recipes/recipe_changes.lua` escreve diretamente
--      `AllRecipes["glasscutter"].ingredients` quando `celestialitems_revert`
--      esta ligada -- o mesmo campo que tocamos em `initialise/modded_recipes.lua`.
--
-- O guarda resolve 1 sempre e 2 por deteccao: guardamos a assinatura vanilla de cada
-- recipe que tocamos (transcrita de `.reference/vanilla/scripts/recipes.lua`, com
-- numero de linha em `baseline`), e so aplicamos a reescrita quando o recipe ainda e'
-- identico ao vanilla. Assim que outro mod mexe nele, a gente para, registra o motivo,
-- e deixa o balanceamento daquele mod intacto.
--
-- A comparacao usa `ingredient.type` e `ingredient.amount`, que sao os unicos campos
-- semanticos de `Ingredient` (ver `.reference/vanilla/scripts/recipe.lua:5-23`); atlas e
-- imagem nao importam para o resultado.

local GLOBAL = rawget(_G, "GLOBAL") or _G
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")
local TechTree = GLOBAL.require("techtree")

local AllRecipes = GLOBAL.AllRecipes

-- { prefab, quantidade } na ordem declarada pelo vanilla.
local BASELINE =
{
    researchlab           = { { "goldnugget", 1 }, { "log", 4 }, { "rocks", 4 } },        -- recipes.lua:366
    researchlab2          = { { "boards", 4 }, { "cutstone", 2 }, { "transistor", 2 } },  -- recipes.lua:367
    goldenaxe             = { { "twigs", 4 }, { "goldnugget", 2 } },                       -- recipes.lua:378
    goldenpickaxe         = { { "twigs", 4 }, { "goldnugget", 2 } },                       -- recipes.lua:380
    goldenshovel          = { { "twigs", 4 }, { "goldnugget", 2 } },                       -- recipes.lua:382
    golden_farm_hoe       = { { "twigs", 4 }, { "goldnugget", 2 } },                       -- recipes.lua:424
    razor                 = { { "twigs", 2 }, { "flint", 2 } },                            -- recipes.lua:388
    compass               = { { "goldnugget", 1 }, { "flint", 1 } },                       -- recipes.lua:391
    transistor            = { { "goldnugget", 2 }, { "cutstone", 1 } },                    -- recipes.lua:446
    lightning_rod         = { { "goldnugget", 4 }, { "cutstone", 1 } },                    -- recipes.lua:552
    birdcage              = { { "papyrus", 2 }, { "goldnugget", 6 }, { "seeds", 2 } },     -- recipes.lua:437
    armormarble           = { { "marble", 6 }, { "rope", 2 } },                            -- recipes.lua:485
    dragonflychest        = { { "dragon_scales", 1 }, { "boards", 4 }, { "goldnugget", 10 } }, -- recipes.lua:545
    portablecookpot_item  = { { "goldnugget", 2 }, { "charcoal", 6 }, { "twigs", 6 } },    -- recipes.lua:85
    portableblender_item  = { { "goldnugget", 2 }, { "transistor", 2 }, { "twigs", 4 } },  -- recipes.lua:86
    portablespicer_item   = { { "goldnugget", 2 }, { "cutstone", 3 }, { "twigs", 6 } },    -- recipes.lua:87
    archive_resonator_item = { { "moonrocknugget", 1 }, { "thulecite", 1 } },              -- recipes.lua:395
    moonrockcrater        = { { "moonrocknugget", 3 } },                                   -- recipes.lua:453
    moondial              = { { "bluemooneye", 1 }, { "moonrocknugget", 2 }, { "ice", 2 } }, -- recipes.lua:554
    moonglassaxe          = { { "twigs", 2 }, { "moonglass", 3 } },                        -- recipes.lua:787
    glasscutter           = { { "log", 1 }, { "moonglass", 5 } },                          -- recipes.lua:788

    -- Receitas que o livro de receitas (craftbook) re-registra com outro nivel de
    -- tecnologia. A assinatura vanilla importa aqui porque `AddRecipe2` com o mesmo
    -- nome SUBSTITUI o objeto Recipe inteiro, inclusive os ingredientes que outro mod
    -- tiver reequilibrado. Ver `M.regate`.
    seedpouch             = { { "slurtle_shellpieces", 2 }, { "cutgrass", 4 }, { "seeds", 2 } },     -- recipes.lua
    icepack               = { { "bearger_fur", 1 }, { "gears", 1 }, { "transistor", 1 } },           -- recipes.lua
    piggyback             = { { "pigskin", 4 }, { "silk", 6 }, { "rope", 2 } },                      -- recipes.lua
    sewing_kit            = { { "log", 1 }, { "silk", 8 }, { "houndstooth", 2 } },                   -- recipes.lua
    flowerhat             = { { "petals", 12 } },                                                    -- recipes.lua
    purpleamulet          = { { "goldnugget", 6 }, { "nightmarefuel", 4 }, { "purplegem", 2 } },     -- recipes.lua
    amulet                = { { "goldnugget", 3 }, { "nightmarefuel", 2 }, { "redgem", 1 } },        -- recipes.lua
    blueamulet            = { { "goldnugget", 3 }, { "bluegem", 1 } },                                -- recipes.lua
    umbrella              = { { "twigs", 6 }, { "pigskin", 1 }, { "silk", 2 } },                      -- recipes.lua
    molehat               = { { "mole", 2 }, { "transistor", 2 }, { "wormlight", 1 } },               -- recipes.lua
    minerhat              = { { "strawhat", 1 }, { "goldnugget", 1 }, { "fireflies", 1 } },           -- recipes.lua
    backpack              = { { "cutgrass", 4 }, { "twigs", 4 } },                                    -- recipes.lua
    armorslurper          = { { "slurper_pelt", 6 }, { "rope", 2 }, { "nightmarefuel", 2 } },         -- recipes.lua
    icehat                = { { "transistor", 2 }, { "rope", 4 }, { "ice", 10 } },                    -- recipes.lua
    beefalohat            = { { "beefalowool", 8 }, { "horn", 1 } },                                  -- recipes.lua
    earmuffshat           = { { "rabbit", 2 }, { "twigs", 1 } },                                      -- recipes.lua
    winterhat             = { { "beefalowool", 4 }, { "silk", 4 } },                                  -- recipes.lua
    beehat                = { { "silk", 8 }, { "rope", 1 } },                                         -- recipes.lua
    trunkvest_summer      = { { "trunk_summer", 1 }, { "silk", 8 } },                                 -- recipes.lua
    bushhat               = { { "strawhat", 1 }, { "rope", 1 }, { "dug_berrybush", 1 } },             -- recipes.lua
    catcoonhat            = { { "coontail", 1 }, { "silk", 4 } },                                     -- recipes.lua
    sweatervest           = { { "houndstooth", 8 }, { "silk", 6 } },                                  -- recipes.lua
    eyebrellahat          = { { "deerclops_eyeball", 1 }, { "twigs", 15 }, { "boneshard", 4 } },       -- recipes.lua
    watermelonhat         = { { "watermelon", 1 }, { "twigs", 3 } },                                  -- recipes.lua
    featherhat            = { { "feather_crow", 3 }, { "feather_robin", 2 }, { "tentaclespots", 2 } }, -- recipes.lua
    hawaiianshirt         = { { "papyrus", 3 }, { "silk", 3 }, { "cactus_flower", 5 } },               -- recipes.lua
    beargervest           = { { "bearger_fur", 1 }, { "sweatervest", 1 }, { "rope", 2 } },             -- recipes.lua
    cane                  = { { "goldnugget", 2 }, { "walrus_tusk", 1 }, { "twigs", 4 } },             -- recipes.lua
    tophat                = { { "silk", 6 } },                                                        -- recipes.lua
    strawhat              = { { "cutgrass", 12 } },                                                   -- recipes.lua
    reflectivevest        = { { "rope", 1 }, { "feather_robin", 3 }, { "pigskin", 2 } },               -- recipes.lua
    rainhat               = { { "mole", 2 }, { "strawhat", 1 }, { "boneshard", 1 } },                  -- recipes.lua
    raincoat              = { { "tentaclespots", 2 }, { "rope", 2 }, { "boneshard", 2 } },             -- recipes.lua
    trunkvest_winter      = { { "trunk_winter", 1 }, { "silk", 8 }, { "beefalowool", 2 } },            -- recipes.lua
    bernie_inactive       = { { "beardhair", 2 }, { "beefalowool", 2 }, { "silk", 2 } },               -- recipes.lua
}

local M = {}

M.BASELINE = BASELINE

-- Historico do que aconteceu nesta sessao, para o relatorio de diagnostico.
M.results = {}

-- AddRecipe2 existe apenas no ambiente do modmain, nao como global do jogo
-- (modutil.lua:732 define env.AddRecipe2). Um arquivo require() nao ve esse
-- ambiente, entao quem roda no modmain precisa injetar a funcao aqui.
local add_recipe_2 = nil
local add_recipe_to_filter = nil
local remove_recipe_from_filter = nil
function M.Init(addrecipe2, addrecipetofilter, removerecipefromfilter)
    -- Treat each initialization as a complete API snapshot. Retaining a previous
    -- optional callback when the new environment omits it masks unavailable APIs
    -- and can make station migration tests (or reloads) use stale capabilities.
    add_recipe_2 = addrecipe2
    add_recipe_to_filter = addrecipetofilter
    remove_recipe_from_filter = removerecipefromfilter
end

local function describe(recipe)
    if recipe == nil then
        return nil
    end

    local out = {}
    for i, ing in ipairs(recipe.ingredients or {}) do
        out[#out + 1] = { ing.type, ing.amount }
    end
    -- O construtor de Recipe separa ingredientes de personagem e de tecnologia em
    -- tabelas proprias (recipe.lua:88-95); para comparar com a baseline vanilla e
    -- preciso considera-los tambem, senao toda receita de personagem parece alterada.
    for i, ing in ipairs(recipe.character_ingredients or {}) do
        out[#out + 1] = { ing.type, ing.amount }
    end
    for i, ing in ipairs(recipe.tech_ingredients or {}) do
        out[#out + 1] = { ing.type, ing.amount }
    end
    return out
end

local function same_signature(a, b)
    if a == nil or b == nil then
        return false
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then
            return false
        end
    end
    return true
end

-- Compare the live ingredient array with the exact override from our previous
-- pass. This makes retries idempotent without mistaking a later third-party
-- rewrite for one of our own changes.
local function same_ingredient_list(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] == nil or b[i] == nil
            or a[i].type ~= b[i].type
            or a[i].amount ~= b[i].amount then
            return false
        end
    end
    return true
end

local function copy_ingredient_list(ingredients)
    local copy = {}
    for i, ingredient in ipairs(ingredients or {}) do
        copy[i] = { type = ingredient.type, amount = ingredient.amount }
    end
    return copy
end

local function copy_tech_level(level)
    local copy = {}
    for key, value in pairs(level or {}) do copy[key] = value end
    return copy
end

local function same_tech_level(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key, value in pairs(b) do if a[key] ~= value then return false end end
    return true
end

--- O recipe ainda esta exatamente como o vanilla?
function M.is_untouched(name)
    local recipe = AllRecipes[name]
    if recipe == nil then
        return false
    end

    local baseline = BASELINE[name]
    if baseline == nil then
        -- Sem assinatura registrada nao ha como provar que esta intacto; conservador = falso.
        return false
    end

    return same_signature(baseline, describe(recipe))
end

--- O recipe existe (pode ter sumido por outro mod)?
function M.exists(name)
    return AllRecipes[name] ~= nil
end

-- Modos de `mam_recipe_overrides`:
--   0 = nunca reescrever receitas vanilla (deixa UM e cia intactos)
--   1 = reescrever so enquanto o recipe ainda for vanilla  (padrao, seguro p/ UM Beta)
--   2 = sempre reescrever (comportamento historico de Metals and More)
local function mode()
    return MAMConfig.int("mam_recipe_overrides", 1)
end

--- Aplica (ou nao) uma reescrita de ingredientes, com registro do motivo.
-- @return applied (boolean), reason (string)
function M.apply(name, ingredients)
    local previous = M.results[name]
    local result = { name = name, applied = false, reason = "unknown" }
    M.results[name] = result

    local recipe = AllRecipes[name]
    if recipe == nil then
        result.reason = "missing"
        MAMLog.WarnOnce("recipe_guard.missing." .. name,
            "Receita '%s' nao existe mais -- outro mod a removeu. Override de metalurgia ignorado.", name)
        return false, result.reason
    end

    if previous ~= nil and previous.applied
        and same_ingredient_list(recipe.ingredients, previous.ingredients) then
        result.applied = true
        result.reason = "already-applied"
        result.ingredients = previous.ingredients
        return true, result.reason
    end

    local m = mode()
    if m == 0 then
        result.reason = "disabled"
        return false, result.reason
    end

    if BASELINE[name] == nil then
        -- Sem assinatura nao ha como saber se o recipe esta intacto; em modo 1 isso significa
        -- que o override seria silenciado. Grita, porque e' erro de codigo nosso, nao de compat.
        MAMLog.WarnOnce("recipe_guard.nobaseline." .. name,
            "Override para '%s' registrado sem assinatura vanilla em recipe_guard.BASELINE -- "
            .. "modo seguro nao pode aplica-lo. Adicione a baseline.", name)
        result.reason = "no-baseline"
        if m == 1 then
            return false, result.reason
        end
    end

    if BASELINE[name] ~= nil and not same_signature(BASELINE[name], describe(recipe))
        and not MAMConfig.on("mam_third_party_recipe_integration") then
        result.reason = "third-party-integration-disabled"
        return false, result.reason
    end

    if m == 1 and not same_signature(BASELINE[name], describe(recipe)) then
        result.reason = "changed-by-others"
        MAMLog.WarnOnce("recipe_guard.clobber." .. name,
            "Receita '%s' ja foi alterada por outro mod -- override de metalurgia ignorado para nao "
            .. "sobrescrever aquele balanceamento. Forcar em Opcoes do mod > Recipe overrides.", name)
        return false, result.reason
    end

    recipe.ingredients = ingredients
    result.applied = true
    result.reason = "applied"
    result.ingredients = copy_ingredient_list(ingredients)
    return true, result.reason
end

--- Muda uma receita existente de bancada sem apagar o trabalho de outro mod.
--
-- `AddRecipe2(name, ...)` com um nome ja existente SUBSTITUI o objeto Recipe inteiro
-- (recipe.lua:161 `AllRecipes[name] = self`), entao reimplementar uma receita vanilla
-- para porta-la para o craftbook tambem joga fora os ingredientes que outro mod tiver
-- reequilibrado. Foi exatamente o que a auditoria achou: o UM Beta reescreve
-- `seedpouch` (recipe_changes.lua:135), `catcoonhat` (:141) e `purpleamulet` (:312),
-- e "My Moar Metals" registra as mesmas ~36 receitas com balanceamento proprio.
--
-- Regra: se a receita ainda e' vanilla, usamos a NOSSA lista (comportamento historico
-- do v2.9.3). Se outro mod ja a reequilibrou, mantemos a lista viva daquele mod e
-- mudamos apenas o nivel de tecnologia -- a identidade do craftbook continua nossa,
-- o balanceamento continua de quem o fez.
--
-- @return applied (boolean), reason (string)  reason: "applied" | "kept-others-ingredients"
function M.regate(name, our_ingredients, tech, more_data, filters)
    local result = { name = name, applied = false, reason = "unknown" }
    M.results[name] = result

    local recipe = AllRecipes[name]
    if recipe == nil then
        result.reason = "missing"
        MAMLog.WarnOnce("regate.missing." .. name,
            "Receita '%s' nao existe -- outro mod a removeu. Nao vamos recria-la no craftbook.", name)
        return false, result.reason
    end

    local m = mode()
    if m == 0 then
        result.reason = "disabled"
        return false, result.reason
    end

    if BASELINE[name] == nil then
        result.reason = "no-baseline"
        MAMLog.WarnOnce("regate.nobaseline." .. name,
            "Receita '%s' nao tem assinatura vanilla; migracao para o craftbook recusada.", name)
        return false, result.reason
    end

    local changed_by_others = not same_signature(BASELINE[name], describe(recipe))
    if changed_by_others and not MAMConfig.on("mam_third_party_recipe_integration") then
        result.reason = "third-party-integration-disabled"
        MAMLog.Info("receita '%s' de terceiro preservada: integracao desativada", name)
        return false, result.reason
    end

    -- No modo seguro, uma receita cujo balanceamento vivo diverge da baseline
    -- conserva os ingredientes e todas as demais propriedades do Recipe original.
    local kept_theirs = m == 1 and changed_by_others
    local station_options = {
        nounlock = type(more_data) == "table" and more_data.nounlock == true,
        -- AddRecipe2(nounlock=true) coloca a receita em CRAFTING_STATION, mas nao
        -- define recipe.filter. Preserve esse campo original.
        set_recipe_filter = false,
    }
    if not kept_theirs then
        station_options.ingredients = our_ingredients
    end

    -- Migra o objeto Recipe existente. Nao chamar AddRecipe2 aqui: Recipe2
    -- substitui AllRecipes[name] e recria metadados/callbacks com defaults.
    local applied, reason = M.set_station(name, tech, "CRAFTING_STATION", station_options)
    if not applied then
        result.reason = reason
        return false, result.reason
    end

    result.applied = true
    result.reason = kept_theirs and "kept-others-ingredients" or "applied"
    result.ingredients = copy_ingredient_list(M.live_ingredients(recipe))
    return true, result.reason
end
--- Move uma receita existente para o filtro/tecnologia da War Bench sem
--- recriar o objeto Recipe e sem tocar nos ingredientes de outros mods.
function M.set_station(name, tech, filter, options)
    local key = "station:" .. name
    local previous = M.results[key]
    options = type(options) == "table" and options or {}
    local set_recipe_filter = options.set_recipe_filter ~= false
    if options.nounlock ~= nil and type(options.nounlock) ~= "boolean" then
        return false, "invalid-options"
    end
    if options.ingredients ~= nil then
        if type(options.ingredients) ~= "table" then
            return false, "invalid-ingredients"
        end
        for _, ingredient in ipairs(options.ingredients) do
            if type(ingredient) ~= "table" or ingredient.type == nil or ingredient.amount == nil then
                return false, "invalid-ingredients"
            end
        end
    end
    local requested_ingredients_signature = options.ingredients ~= nil
        and copy_ingredient_list(options.ingredients) or nil
    local result = { name = name, applied = false, reason = "unknown" }
    M.results[key] = result

    local recipe = AllRecipes[name]
    if recipe == nil then
        result.reason = "missing"
        MAMLog.WarnOnce("recipe_station.missing." .. name,
            "Receita '%s' ausente; migracao para a War Bench ignorada.", name)
        return false, result.reason
    end

    -- A successful earlier pass is already committed. Do not repeat it during
    -- the world-task fallback; preserving a later mod's change is safer.
    local filters = GLOBAL.CRAFTING_FILTERS
    local destination = filter ~= nil and filters ~= nil and filters[filter] or nil
    local destination_contains = filter == nil or (destination ~= nil
        and type(destination.default_sort_values) == "table"
        and destination.default_sort_values[name] ~= nil)

    local previous_options = previous ~= nil and previous.options or {}
    local requested_ingredients_match = options.ingredients == nil
        and previous_options.ingredients_signature == nil
        or options.ingredients ~= nil
        and same_ingredient_list(previous_options.ingredients_signature, options.ingredients)
    local options_match = previous_options.remove_special_event == (options.remove_special_event == true)
        and previous_options.clear_hint_msg_if == options.clear_hint_msg_if
        and previous_options.nounlock == options.nounlock
        and (previous_options.set_recipe_filter ~= false) == set_recipe_filter
        and requested_ingredients_match
    local special_event = filters ~= nil and filters.SPECIAL_EVENT or nil
    local special_event_removed = options.remove_special_event ~= true
        or special_event == nil or type(special_event.default_sort_values) ~= "table"
        or special_event.default_sort_values[name] == nil
    local hint_cleared = options.clear_hint_msg_if == nil
        or recipe.hint_msg ~= options.clear_hint_msg_if

    if previous ~= nil and previous.applied
        and previous.tech_input == tech and previous.filter == filter and options_match
        and previous.ingredients_signature ~= nil
        and same_signature(previous.ingredients_signature, describe(recipe))
        and previous.level_signature ~= nil
        and same_tech_level(recipe.level, previous.level_signature)
        and (not set_recipe_filter or recipe.filter == filter)
        and (options.nounlock == nil or recipe.nounlock == options.nounlock)
        and destination_contains and special_event_removed and hint_cleared then
        result.applied = true
        result.reason = "already-applied"
        result.tech_input = tech
        result.filter = filter
        result.options = {
            remove_special_event = options.remove_special_event == true,
            clear_hint_msg_if = options.clear_hint_msg_if,
            nounlock = options.nounlock,
            set_recipe_filter = set_recipe_filter,
            ingredients_signature = requested_ingredients_signature,
        }
        result.ingredients_signature = previous.ingredients_signature
        result.level_signature = previous.level_signature
        return true, result.reason
    end

    if type(tech) ~= "table" then
        result.reason = "invalid-tech"
        MAMLog.WarnOnce("recipe_station.tech." .. name,
            "Tecnologia invalida para '%s'; bancada nao foi alterada.", name)
        return false, result.reason
    end

    if BASELINE[name] ~= nil and not same_signature(BASELINE[name], describe(recipe))
        and not MAMConfig.on("mam_third_party_recipe_integration") then
        result.reason = "third-party-integration-disabled"
        MAMLog.Info("receita '%s' de terceiro nao foi movida: integracao desativada", name)
        return false, result.reason
    end

    -- Prepare every fallible input before mutating the live Recipe or its filters.
    local ok_level, new_level = pcall(TechTree.Create, tech)
    if not ok_level then
        result.reason = "invalid-tech"
        MAMLog.WarnOnce("recipe_station.create_tech." .. name,
            "Nao foi possivel preparar a tecnologia de '%s'; bancada nao foi alterada.", name)
        return false, result.reason
    end

    local target_filter
    local old_filters = {}
    local target_needs_add = false
    if filter ~= nil then
        if type(add_recipe_to_filter) ~= "function" then
            result.reason = "filter-api-unavailable"
            MAMLog.WarnOnce("recipe_station.filter." .. name,
                "AddRecipeToFilter indisponivel para '%s'; receita nao foi alterada.", name)
            return false, result.reason
        end

        local filters = GLOBAL.CRAFTING_FILTERS
        target_filter = filters ~= nil and filters[filter] or nil
        if target_filter == nil or type(target_filter.default_sort_values) ~= "table" then
            result.reason = "invalid-filter"
            MAMLog.WarnOnce("recipe_station.invalid_filter." .. name,
                "Filtro de destino '%s' invalido para '%s'; receita nao foi alterada.",
                tostring(filter), name)
            return false, result.reason
        end

        target_needs_add = target_filter.default_sort_values[name] == nil
        for filter_name, filter_def in pairs(filters) do
            if filter_name ~= filter and filter_name ~= "FAVORITES"
                and filter_name ~= "CHARACTER"
                and (filter_name ~= "SPECIAL_EVENT" or options.remove_special_event == true)
                and type(filter_def.default_sort_values) == "table"
                and filter_def.default_sort_values[name] ~= nil then
                old_filters[#old_filters + 1] = filter_name
            end
        end

        -- If old filters exist, we must be able to remove them. Do not silently
        -- report success while leaving the recipe visible in multiple categories.
        if #old_filters > 0 and type(remove_recipe_from_filter) ~= "function" then
            result.reason = "filter-api-unavailable"
            MAMLog.WarnOnce("recipe_station.remove_api." .. name,
                "RemoveRecipeFromFilter indisponivel para '%s'; receita nao foi alterada.", name)
            return false, result.reason
        end

        -- Add the destination first. If the API errors, the original recipe and
        -- all former filters remain untouched. Roll back a partial target insert.
        if target_needs_add then
            local added, add_error = pcall(add_recipe_to_filter, name, filter)
            if not added then
                if type(remove_recipe_from_filter) == "function" then
                    pcall(remove_recipe_from_filter, name, filter)
                end
                result.reason = "filter-add-failed"
                MAMLog.WarnOnce("recipe_station.add_failed." .. name,
                    "Nao foi possivel adicionar '%s' ao filtro '%s': %s",
                    name, tostring(filter), tostring(add_error))
                return false, result.reason
            end
        end

        -- Remove former filters only after the destination is known to exist.
        -- On failure, restore those already removed and undo the new destination.
        local removed = {}
        if type(remove_recipe_from_filter) == "function" then
            for _, old_filter in ipairs(old_filters) do
                local removed_ok, remove_error = pcall(remove_recipe_from_filter, name, old_filter)
                if not removed_ok then
                    for _, restore_filter in ipairs(removed) do
                        pcall(add_recipe_to_filter, name, restore_filter)
                    end
                    if target_needs_add then
                        pcall(remove_recipe_from_filter, name, filter)
                    end
                    result.reason = "filter-remove-failed"
                    MAMLog.WarnOnce("recipe_station.remove_failed." .. name,
                        "Nao foi possivel migrar '%s' do filtro '%s': %s",
                        name, tostring(old_filter), tostring(remove_error))
                    return false, result.reason
                end
                removed[#removed + 1] = old_filter
            end
        end
    end

    -- Commit the Recipe fields only after filter migration succeeds.
    recipe.level = new_level
    if filter ~= nil and set_recipe_filter then
        recipe.filter = filter
    end
    if options.ingredients ~= nil then
        recipe.ingredients = options.ingredients
    end
    if options.nounlock ~= nil then
        recipe.nounlock = options.nounlock
    end
    if options.clear_hint_msg_if ~= nil and recipe.hint_msg == options.clear_hint_msg_if then
        recipe.hint_msg = nil
    end

    result.applied = true
    result.reason = "applied"
    result.tech_input = tech
    result.filter = filter
    result.options = {
        remove_special_event = options.remove_special_event == true,
        clear_hint_msg_if = options.clear_hint_msg_if,
        nounlock = options.nounlock,
        set_recipe_filter = set_recipe_filter,
        ingredients_signature = requested_ingredients_signature,
    }
    result.ingredients_signature = describe(recipe)
    result.level_signature = copy_tech_level(recipe.level)
    MAMLog.Info("receita '%s' movida para tecnologia %s / filtro %s sem reescrever ingredientes",
        name, tostring(tech), tostring(filter))
    return true, result.reason
end

--- Copia os Ingredient vivos de uma receita, nas tres tabelas que Recipe separa.
-- Os objetos sao reutilizados (Recipe._ctor apenas os insere em tabelas novas), o que
-- preserva atlas, imagem e `deconstruct` exatamente como o outro mod configurou.
function M.live_ingredients(recipe)
    local out = {}
    if recipe == nil then
        return out
    end
    for _, ing in ipairs(recipe.ingredients or {}) do
        out[#out + 1] = ing
    end
    for _, ing in ipairs(recipe.character_ingredients or {}) do
        out[#out + 1] = ing
    end
    for _, ing in ipairs(recipe.tech_ingredients or {}) do
        out[#out + 1] = ing
    end
    return out
end

--- Linha de diagnostico: quantos overrides entraram, quantos cederam e por que.
function M.dump()
    local applied, applied_names = 0, {}
    local reasons = {}

    for name, r in pairs(M.results) do
        if r.applied then
            applied = applied + 1
            table.insert(applied_names, name)
        else
            reasons[r.reason] = (reasons[r.reason] or 0) + 1
        end
    end

    local parts = {}
    for reason, count in pairs(reasons) do
        table.insert(parts, reason .. "=" .. count)
    end
    table.sort(parts)
    table.sort(applied_names)

    print(("[MAM][recipe_guard] modo=%d aplicados=%d [%s] pulados: %s")
        :format(mode(), applied, table.concat(applied_names, " "), table.concat(parts, ", ")))

    return applied, reasons, applied_names
end

return M
