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
    add_recipe_2 = addrecipe2
    add_recipe_to_filter = addrecipetofilter or add_recipe_to_filter
    remove_recipe_from_filter = removerecipefromfilter or remove_recipe_from_filter
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
    local result = { name = name, applied = false, reason = "unknown" }
    M.results[name] = result

    local recipe = AllRecipes[name]
    if recipe == nil then
        result.reason = "missing"
        MAMLog.WarnOnce("recipe_guard.missing." .. name,
            "Receita '%s' nao existe mais -- outro mod a removeu. Override de metalurgia ignorado.", name)
        return false, result.reason
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

    if add_recipe_2 == nil then
        result.reason = "not-initialised"
        MAMLog.Error("recipe_guard.regate('%s') chamado sem MAMRecipeGuard.Init(AddRecipe2)", tostring(name))
        return false, result.reason
    end

    local m = mode()
    if m == 0 then
        result.reason = "disabled"
        return false, result.reason
    end

    local ingredients = our_ingredients
    local kept_theirs = false

    if m == 1 and BASELINE[name] ~= nil and not same_signature(BASELINE[name], describe(recipe)) then
        ingredients = M.live_ingredients(recipe)
        kept_theirs = true
        MAMLog.WarnOnce("regate.keep." .. name,
            "Receita '%s' foi reequilibrada por outro mod -- movemos para o craftbook mas "
            .. "preservamos os ingredientes daquele mod.", name)
    end

    add_recipe_2(name, ingredients, tech, more_data, filters)

    result.applied = true
    result.reason = kept_theirs and "kept-others-ingredients" or "applied"
    return true, result.reason
end

--- Move uma receita existente para o filtro/tecnologia da War Bench sem
--- recriar o objeto Recipe e sem tocar nos ingredientes de outros mods.
function M.set_station(name, tech, filter)
    local result = { name = name, applied = false, reason = "unknown" }
    M.results["station:" .. name] = result

    local recipe = AllRecipes[name]
    if recipe == nil then
        result.reason = "missing"
        MAMLog.WarnOnce("recipe_station.missing." .. name,
            "Receita '%s' ausente; migracao para a War Bench ignorada.", name)
        return false, result.reason
    end

    if type(tech) ~= "table" then
        result.reason = "invalid-tech"
        MAMLog.WarnOnce("recipe_station.tech." .. name,
            "Tecnologia invalida para '%s'; bancada nao foi alterada.", name)
        return false, result.reason
    end

    -- Recipe.level e a unica parte de tecnologia que muda. Os ingredientes,
    -- atlas, imagem, flags, builder tags e callbacks do outro mod permanecem.
    recipe.level = TechTree.Create(tech)

    if filter ~= nil then
        if add_recipe_to_filter == nil then
            result.reason = "filter-api-unavailable"
            MAMLog.WarnOnce("recipe_station.filter." .. name,
                "AddRecipeToFilter indisponivel para '%s'; tecnologia alterada, filtro nao.", name)
            return false, result.reason
        end

        -- Remove the recipe from its former vanilla/mod filters so it appears
        -- in the War Bench station filter only.
        if remove_recipe_from_filter ~= nil and GLOBAL.CRAFTING_FILTERS ~= nil then
            for filter_name, filter_def in pairs(GLOBAL.CRAFTING_FILTERS) do
                if filter_name ~= filter and filter_name ~= "FAVORITES"
                    and filter_name ~= "CHARACTER" and filter_name ~= "SPECIAL_EVENT"
                    and filter_def.default_sort_values ~= nil
                    and filter_def.default_sort_values[name] ~= nil then
                    remove_recipe_from_filter(name, filter_name)
                end
            end
        end
        add_recipe_to_filter(name, filter)
        recipe.filter = filter
    end

    result.applied = true
    result.reason = "applied"
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
