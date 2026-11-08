require "tuning"

local smelterrecipes = {}

function AddSmelterSmelterRecipe(smelter, recipe)
	if not smelterrecipes[smelter] then
		smelterrecipes[smelter] = {}
	end
	smelterrecipes[smelter][recipe.name] = recipe
end

local smelteringredients = {}

function AddSmelterIngredientValues(names, tags, cancook, candry)
	for _,name in pairs(names) do
		smelteringredients[name] = { tags= {}}
		for tagname,tagval in pairs(tags) do
			smelteringredients[name].tags[tagname] = tagval
		end
	end
end

function IsModProduct(smelter, name)
	local enabledmods = ModManager:GetEnabledModNames()
    for i,v in ipairs(enabledmods) do
        local mod = ModManager:GetMod(v)
        if mod.smelterrecipes and mod.smelterrecipes[smelter] and table.contains(mod.smelterrecipes[smelter], name) then
            return true
        end
    end
    return false
end

AddSmelterIngredientValues({"junk_dust"}, 			{metal = 0.5})

AddSmelterIngredientValues({"copper_dust"}, 		{copper = 0.5, metal = 0.5})
AddSmelterIngredientValues({"copper_ore"}, 			{copper = 1, metal = 1})
AddSmelterIngredientValues({"copper_ingot"}, 		{copper = 3, metal = 3})

AddSmelterIngredientValues({"iron_dust"}, 			{iron = 0.5, metal = 0.5})
AddSmelterIngredientValues({"iron_ore"}, 			{iron = 1, metal = 1})
AddSmelterIngredientValues({"iron_ingot"}, 			{iron = 3, metal = 3})

--AddSmelterIngredientValues({"steelwool"}, 			{iron = 2, steel = 1, metal = 1})
AddSmelterIngredientValues({"nightmarefuel"}, 			{iron = 2, steel = 1, metal = 1})

AddSmelterIngredientValues({"gold_dust"},			{gold = 0.5, metal = 0.5})
AddSmelterIngredientValues({"goldnugget"},			{gold = 1, metal = 1})
AddSmelterIngredientValues({"gold_ingot"},			{gold = 3, metal = 3})

AddSmelterIngredientValues({"moonglass"},			{moonglass = 1})
AddSmelterIngredientValues({"moonrocknugget"},		{moon = 1, mineral = 1})
AddSmelterIngredientValues({"moonglass_ingot"},		{moonglass = 2, moon = 2})

AddSmelterIngredientValues({"rocks", "nitre"},		{mineral = 1})

AddSmelterIngredientValues({"redgem_shard"},		{red = 1, gem = 0.25})
AddSmelterIngredientValues({"bluegem_shard"},		{blue = 1, gem = 0.25})
AddSmelterIngredientValues({"yellowgem_shard"},		{yellow = 1, gem = 0.25})
AddSmelterIngredientValues({"greengem_shard"},		{yellow = 0.5, blue = 0.5, gem = 0.25})
AddSmelterIngredientValues({"orangegem_shard"},		{yellow = 0.5, red = 0.5, gem = 0.25})
AddSmelterIngredientValues({"purplegem_shard"},		{blue = 0.5, red = 0.5, gem = 0.25})

local function IsSmelterIngredient(prefabname)
    return smelteringredients[prefabname] ~= nil
end

local smelting_products = require("smelting_products")

for k,recipe in pairs (smelting_products) do
	AddSmelterSmelterRecipe("metal_smelter", recipe)
end

local function GetSmelterIngredientValues(prefablist)
    local prefabs = {}
    local tags = {}
    for k,v in pairs(prefablist) do
        local name = v

        prefabs[name] = (prefabs[name] or 0) + 1

        local data = smelteringredients[name]

        if data ~= nil then
            for kk, vv in pairs(data.tags) do
                tags[kk] = (tags[kk] or 0) + vv
            end
        end
    end
    return { tags = tags, names = prefabs }
end

local function GetSmelterRecipe(smelter, product)
	local recipes = smelterrecipes[smelter] or {}
	return recipes[product]
end

function GetCandidateSmelterRecipes(smelter, ingdata)
	local recipes = smelterrecipes[smelter] or {}
	local candidates = {}

	--find all potentially valid recipes
	for k,v in pairs(recipes) do
		if v.test(smelter, ingdata.names, ingdata.tags) then
			table.insert(candidates, v)
		end
	end

	table.sort( candidates, function(a,b) return (a.priority or 0) > (b.priority or 0) end )
	if #candidates > 0 then
		--find the set of highest priority recipes
		local top_candidates = {}
		local idx = 1
		local val = candidates[1].priority or 0

		for k,v in ipairs(candidates) do
			if k > 1 and (v.priority or 0) < val then
				break
			end
			table.insert(top_candidates, v)
		end
		return top_candidates
	end

	return candidates
end

local function CalculateSmelterRecipe(smelter, names)
	local ingdata = GetSmelterIngredientValues(names)
	local candidates = GetCandidateSmelterRecipes(smelter, ingdata)

	table.sort( candidates, function(a,b) return (a.weight or 1) > (b.weight or 1) end )
	local total = 0
	for k,v in pairs(candidates) do
		total = total + (v.weight or 1)
	end

	local val = math.random()*total
	local idx = 1
	while idx <= #candidates do
		val = val - candidates[idx].weight
		if val <= 0 then
			return candidates[idx].name, candidates[idx].cooktime or 1
		end

		idx = idx+1
	end
end

---------------------------------------------------------------------------
-- Motor de lote e de previsao (Etapa 1)
--
-- O que permanece identico ao original: a IDENTIDADE do produto continua
-- escolhida pelas mesmas test/priority/weight sobre a mesma tabela de tags.
-- O que muda: conhecido o produto, calculamos QUANTAS unidades a carga atual
-- comporta (custo por unidade declarado em smelting_products) e quais pecas
-- exatas serao consumidas, devolvendo o resto.
--
-- Nenhum custo foi inventado: cada cost espelha o limiar da test original.
---------------------------------------------------------------------------

local MAMConfig = require("mam/config")

--- Versao com pilhas: items = { {prefab=..., count=...}, ... }
--- A contagem por peca e obrigatoria para a fundicao em lote fechar contas.
local function GetSmelterIngredientValuesCounted(items)
    local names = {}
    local tags = {}
    for _, item in ipairs(items) do
        local count = item.count or 1
        if count > 0 then
            names[item.prefab] = (names[item.prefab] or 0) + count
            local data = smelteringredients[item.prefab]
            if data ~= nil then
                for tagname, tagval in pairs(data.tags) do
                    tags[tagname] = (tags[tagname] or 0) + tagval * count
                end
            end
        end
    end
    return { tags = tags, names = names }
end

local function recipe_cost(recipe)
    if type(recipe.cost) == "table" then
        return recipe.cost.tags or {}, recipe.cost.names or {}
    end
    return {}, {}
end

local function batch_cap(recipe)
    local cap = MAMConfig.int("mam_batch_cap", 10)
    if recipe.max_batch ~= nil then
        cap = math.min(cap, recipe.max_batch)
    end
    if cap < 1 then
        cap = 1
    end
    return cap
end

--- Quantas unidades o lote atual produz para o recipe.
--- Sem custo declarado, produz 1 (comportamento original).
--- `opts` permite que a UI use os valores do SERVIDOR (publicados pela net var
--- do plano) em vez das proprias opcoes locais, que podem divergir em MP.
local function batch_count_for(recipe, ingdata, opts)
    local batch_on
    if opts ~= nil and opts.batch ~= nil then
        batch_on = opts.batch and true or false
    else
        batch_on = MAMConfig.on("mam_batch")
    end

    local cap
    if opts ~= nil and opts.cap ~= nil and opts.cap > 0 then
        cap = opts.cap
    else
        cap = batch_cap(recipe)
    end
    -- O teto intrinseco do produto (max_batch) vale nos dois casos.
    if recipe.max_batch ~= nil then
        cap = math.min(cap, recipe.max_batch)
    end
    if cap < 1 then
        cap = 1
    end

    if not batch_on then
        return 1
    end

    local cost_tags, cost_names = recipe_cost(recipe)
    if next(cost_tags) == nil and next(cost_names) == nil then
        return 1
    end

    local n = cap
    for tagname, need in pairs(cost_tags) do
        if need > 0 then
            local possible = math.floor((ingdata.tags[tagname] or 0) / need + 1e-6)
            if possible < n then
                n = possible
            end
        end
    end
    for prefab, need in pairs(cost_names) do
        if need > 0 then
            local possible = math.floor((ingdata.names[prefab] or 0) / need + 1e-6)
            if possible < n then
                n = possible
            end
        end
    end

    if n < 1 then
        n = 1
    end
    return n
end

--- Escolhe as pecas exatas consumidas pelo lote, na ordem dos slots.
--- items: { {prefab, count, slot}, ... }
local function plan_consumption(recipe, n, items)
    local cost_tags, cost_names = recipe_cost(recipe)

    local need_tags = {}
    local need_names = {}
    for tagname, need in pairs(cost_tags) do
        need_tags[tagname] = need * n
    end
    for prefab, need in pairs(cost_names) do
        need_names[prefab] = need * n
    end

    local taken = {}
    for i = 1, #items do
        taken[i] = 0
    end

    -- Passo 1: pre-requisitos nomeados (ex.: adamantio exige barra de ferro).
    for i, item in ipairs(items) do
        local need = need_names[item.prefab]
        if need ~= nil and need > 0 then
            local take = math.min(need, item.count)
            taken[i] = take
            need_names[item.prefab] = need - take
        end
    end

    local function still_needed()
        for _, v in pairs(need_tags) do
            if v > 1e-6 then
                return true
            end
        end
        return false
    end

    -- Passo 2: cobre os requisitos por tag sem exceder o necessario no item.
    for i, item in ipairs(items) do
        if still_needed() then
            local data = smelteringredients[item.prefab]
            if data ~= nil then
                local free = item.count - taken[i]
                if free > 0 then
                    local k = free
                    for tagname, val in pairs(data.tags) do
                        local need = need_tags[tagname]
                        if need ~= nil and need > 1e-6 and val > 0 then
                            local fits = math.ceil(need / val - 1e-6)
                            if fits < k then
                                k = fits
                            end
                        end
                    end
                    if k > 0 then
                        taken[i] = taken[i] + k
                        for tagname, val in pairs(data.tags) do
                            if need_tags[tagname] ~= nil then
                                need_tags[tagname] = need_tags[tagname] - val * k
                            end
                        end
                    end
                end
            end
        end
    end

    -- Algumas receitas originais aceitam caminhos alternativos no teste.
    -- Se o caminho escolhido nao satisfaz o custo padrao, nao podemos deixar
    -- a carga intacta: isso permitiria repetir a producao sem consumir itens.
    local unmet = false
    for _, need in pairs(need_names) do
        if need > 1e-6 then
            unmet = true
            break
        end
    end
    if not unmet then
        for _, need in pairs(need_tags) do
            if need > 1e-6 then
                unmet = true
                break
            end
        end
    end
    if recipe.consume_all_if_unmatched and unmet then
        -- O fallback de nitre existe por causa dos fragmentos de gema.
        -- Consome somente os itens que fornecem a tag gem; outros itens que
        -- eventualmente estejam no container permanecem intactos.
        for i, item in ipairs(items) do
            local data = smelteringredients[item.prefab]
            if data ~= nil and (data.tags.gem or 0) > 0 then
                taken[i] = item.count
            end
        end
    end

    local consumed = {}
    local leftovers = {}
    for i, item in ipairs(items) do
        if taken[i] > 0 then
            table.insert(consumed, { slot = item.slot, prefab = item.prefab, count = taken[i] })
        end
        local rest = item.count - taken[i]
        if rest > 0 then
            table.insert(leftovers, { slot = item.slot, prefab = item.prefab, count = rest })
        end
    end
    return consumed, leftovers
end

local function smelt_time(recipe, n, opts)
    local base = recipe.cooktime or 1

    local batch_on
    if opts ~= nil and opts.batch ~= nil then
        batch_on = opts.batch and true or false
    else
        batch_on = MAMConfig.on("mam_batch")
    end

    if not batch_on or n <= 1 then
        return base
    end

    local growth = (opts ~= nil and opts.batch_time ~= nil and opts.batch_time
        or MAMConfig.int("mam_batch_time", 25)) / 100
    if growth <= 0 then
        return base
    end
    return base * (1 + growth * (n - 1))
end

--- items = { {prefab=..., count=..., slot=...}, ... }
--- Plano completo, com sorteio: usado na hora de COMECAR a fundicao.
local function CalculateSmelterPlan(smelter, items)
    local ingdata = GetSmelterIngredientValuesCounted(items)
    local candidates = GetCandidateSmelterRecipes(smelter, ingdata)

    local plan = {
        tags = ingdata.tags,
        names = ingdata.names,
        possibilities = {},
    }

    for _, recipe in ipairs(candidates) do
        table.insert(plan.possibilities, recipe.name)
    end

    if #candidates == 0 then
        plan.state = "invalid"
        plan.reason = "unknown"
        return plan
    end

    table.sort(candidates, function(a, b) return (a.weight or 1) > (b.weight or 1) end)

    local total = 0
    for _, recipe in ipairs(candidates) do
        total = total + (recipe.weight or 1)
    end

    local chosen = candidates[#candidates]
    local roll = math.random() * total
    for _, recipe in ipairs(candidates) do
        roll = roll - (recipe.weight or 1)
        if roll <= 0 then
            chosen = recipe
            break
        end
    end

    local n = batch_count_for(chosen, ingdata)
    local consumed, leftovers = plan_consumption(chosen, n, items)

    plan.state = "ready"
    plan.product = chosen.name
    plan.count = n
    plan.recipe = chosen
    plan.smelttime = smelt_time(chosen, n)
    plan.consumed = consumed
    plan.leftovers = leftovers
    plan.deterministic = #candidates == 1
    return plan
end

--- Previsao sem sorteio nem efeitos colaterais: usado pela UI.
--- Com empate de prioridade mostra o conjunto de possibilidades; assim o
--- cliente nunca precisa adivinhar uma escolha aleatoria do servidor.
local function ForecastSmelterPlan(smelter, items, opts)
    local ingdata = GetSmelterIngredientValuesCounted(items)
    local candidates = GetCandidateSmelterRecipes(smelter, ingdata)

    local plan = {
        tags = ingdata.tags,
        names = ingdata.names,
        possibilities = {},
    }

    if #candidates == 0 then
        plan.state = "invalid"
        plan.reason = "unknown"
        return plan
    end

    local best = candidates[1].priority or 0
    for _, recipe in ipairs(candidates) do
        if (recipe.priority or 0) == best then
            table.insert(plan.possibilities, recipe.name)
        end
    end

    plan.deterministic = #plan.possibilities == 1

    if MAMConfig.int("mam_forecast", 2) < 2 and #plan.possibilities > 1 then
        plan.state = "ambiguous"
        plan.reason = "ambiguous"
        return plan
    end

    plan.ambiguous = #plan.possibilities > 1
    plan.outcomes = {}

    -- Empates de prioridade podem apontar para receitas com custos diferentes.
    -- Calcular cada resultado separadamente evita mostrar a quantidade/tempo
    -- da primeira receita como se tambem valesse para todas as alternativas.
    for _, candidate in ipairs(candidates) do
        local count = batch_count_for(candidate, ingdata, opts)
        table.insert(plan.outcomes, {
            product = candidate.name,
            count = count,
            smelttime = smelt_time(candidate, count, opts),
        })
    end

    local primary = plan.outcomes[1]
    if primary == nil then
        plan.state = "ambiguous"
        return plan
    end

    plan.state = "ready"
    plan.product = primary.product
    plan.count = primary.count
    plan.smelttime = primary.smelttime
    plan.max_batch = batch_cap((smelterrecipes[smelter] or {})[primary.product])
    return plan
end

return {
    CalculateSmelterRecipe = CalculateSmelterRecipe,
    IsSmelterIngredient = IsSmelterIngredient,
    recipes = smelterrecipes,
    smelteringredients = smelteringredients,
    GetSmelterRecipe = GetSmelterRecipe,
    GetSmelterIngredientValues = GetSmelterIngredientValues,
    GetSmelterIngredientValuesCounted = GetSmelterIngredientValuesCounted,
    CalculateSmelterPlan = CalculateSmelterPlan,
    ForecastSmelterPlan = ForecastSmelterPlan,
}
