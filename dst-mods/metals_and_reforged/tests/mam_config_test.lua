package.path = "./scripts/?.lua;" .. package.path

local Config = require("mam/config")
local passed = 0

local function equal(actual, expected, label)
    assert(actual == expected, ("%s: esperado %s, recebido %s"):format(label, tostring(expected), tostring(actual)))
    passed = passed + 1
end

local allowed = {
    mam_batch = { 0, 1 },
    mam_batch_time = { 0, 25, 50, 75 },
    mam_forecast = { 0, 1, 2 },
    mam_leftovers = { 0, 1 },
    mam_batch_cap = { 4, 10, 20 },
    mam_recipe_overrides = { 0, 1, 2 },
    mam_third_party_recipe_integration = { 0, 1 },
    mam_allow_third_party_drop_overrides = { 0, 1 },
    mam_extra_drops = { 0, 1 },
    mam_drops_mode = { 1, 2 },
    mam_drops_normalise = { 0, 1 },
    mam_drop_boulders = { 0, 1 },
    mam_drop_stalagmites = { 0, 1 },
    mam_drop_chess = { 0, 1 },
    mam_drop_hounds = { 0, 1, 2 },
    mam_drop_marbletree = { 0, 1 },
    mam_drop_marbleshrub = { 0, 1 },
    mam_drop_shark = { 0, 1 },
    mam_drop_rocky = { 0, 1 },
    mam_drop_rubble = { 0, 1 },
    mam_drop_ancient_statues = { 0, 1 },
    mam_drop_knight = { 0, 1 },
    mam_drop_rook = { 0, 1 },
    mam_drop_bishop = { 0, 1 },
    mam_drop_chessjunk = { 0, 1 },
    mam_drop_firehound = { 0, 1 },
    mam_drop_icehound = { 0, 1 },
    mam_drop_slurtle = { 0, 1 },
    mam_drop_snurtle = { 0, 1 },
    mam_drop_boulders_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_stalagmites_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_chess_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_hounds_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_marbletree_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_shark_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_rocky_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_rubble_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_ancient_statues_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_knight_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_rook_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_bishop_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_chessjunk_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_firehound_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_icehound_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_slurtle_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_snurtle_chance = { 25, 50, 75, 100, 125, 150 },
    mam_drop_marbleshrub_quantity = { 0, 100, 200, 300 },
    mam_robot_smelting = { 0, 1 },
    mam_language = { "ptbr", "en" },
}

local defaults = {
    mam_batch = 1, mam_batch_time = 25, mam_forecast = 2, mam_leftovers = 1,
    mam_batch_cap = 10, mam_recipe_overrides = 1, mam_third_party_recipe_integration = 1,
    mam_allow_third_party_drop_overrides = 0, mam_extra_drops = 1,
    mam_drops_mode = 1, mam_drops_normalise = 0, mam_drop_boulders = 1,
    mam_drop_stalagmites = 1, mam_drop_chess = 1, mam_drop_hounds = 1,
    mam_drop_marbletree = 1, mam_drop_marbleshrub = 1, mam_drop_shark = 1,
    mam_drop_rocky = 1, mam_drop_rubble = 1, mam_drop_ancient_statues = 1,
    mam_drop_knight = 1, mam_drop_rook = 1, mam_drop_bishop = 1, mam_drop_chessjunk = 1,
    mam_drop_firehound = 1, mam_drop_icehound = 1, mam_drop_slurtle = 1, mam_drop_snurtle = 1,
    mam_drop_boulders_chance = 100, mam_drop_stalagmites_chance = 100,
    mam_drop_chess_chance = 100, mam_drop_hounds_chance = 100,
    mam_drop_marbletree_chance = 100, mam_drop_shark_chance = 100,
    mam_drop_rocky_chance = 100, mam_drop_rubble_chance = 100, mam_drop_ancient_statues_chance = 100,
    mam_drop_knight_chance = 100, mam_drop_rook_chance = 100, mam_drop_bishop_chance = 100,
    mam_drop_chessjunk_chance = 100, mam_drop_firehound_chance = 100, mam_drop_icehound_chance = 100,
    mam_drop_slurtle_chance = 100, mam_drop_snurtle_chance = 100,
    mam_drop_marbleshrub_quantity = 100, mam_robot_smelting = 0,
    mam_language = "ptbr",
}

-- Todos os valores de configuracao publicados devem ser aceitos sem alteracao.
for key, options in pairs(allowed) do
    for _, value in ipairs(options) do
        Config.Init(function(k) return k == key and value or nil end)
        equal(Config.get(key), value, key .. " aceita " .. value)
    end
end

-- Ausencia, tipo errado e valores fora da lista retornam o default canonico.
for key, default in pairs(defaults) do
    Config.Init(function(k)
        if k == key then return "invalid" end
    end)
    equal(Config.get(key), default, key .. " rejeita string")
    Config.Init(function(k)
        if k == key then return 999 end
    end)
    equal(Config.get(key), default, key .. " rejeita valor fora da lista")
    Config.Init(function() error("getter indisponivel") end)
    equal(Config.get(key), default, key .. " usa default se getter falhar")
end

-- Overrides do servidor sao aceitos apenas quando pertencem ao mesmo enum.
Config.Init(function(k)
    if k == "mam_batch_cap" then return 10 end
    if k == "mam_forecast" then return 2 end
    if k == "mam_drops_mode" then return 1 end
end, { mam_batch_cap = 20, mam_forecast = 99, mam_drops_mode = "2" })
equal(Config.get("mam_batch_cap"), 20, "override valido aplicado")
equal(Config.get("mam_forecast"), 2, "override numerico invalido ignorado")
equal(Config.get("mam_drops_mode"), 1, "override de tipo errado ignorado")

-- As integracoes sao independentes: desligar receitas de terceiros nao altera
-- os overrides de custo vanilla; o Rewrite de drops exige opt-in separado.
Config.Init(function(k)
    if k == "mam_third_party_recipe_integration" then return 0 end
    if k == "mam_recipe_overrides" then return 1 end
    if k == "mam_allow_third_party_drop_overrides" then return 0 end
    if k == "mam_drops_mode" then return 2 end
end)
equal(Config.on("mam_third_party_recipe_integration"), false, "integracao de receitas de terceiros desligavel")
equal(Config.get("mam_recipe_overrides"), 1, "override vanilla independente da integracao de terceiros")
equal(Config.on("mam_allow_third_party_drop_overrides"), false, "substituicao de loot de terceiros exige opt-in")
equal(Config.get("mam_drops_mode"), 2, "modo Rewrite continua selecionavel separadamente")
equal(Config.get("mam_drop_hounds_chance"), 100, "chance de hounds tem ajuste independente")
equal(Config.get("mam_drop_marbleshrub_quantity"), 100, "quantidade do arbusto tem ajuste independente")

-- set() tambem nao permite contornar a validacao.
Config.set("mam_batch", 0)
equal(Config.get("mam_batch"), 0, "set valido aplicado")
Config.set("mam_batch", "1")
equal(Config.get("mam_batch"), 0, "set invalido ignorado")
Config.set("mam_batch_cap", 4.5)
equal(Config.get("mam_batch_cap"), 10, "set fracionario ignorado")

-- Chaves reservadas sem implementacao nao devem aparentar ser configuracoes ativas.
equal(Config.get("mam_metalschest"), nil, "baú dedicado removido; compatibilidade de saves antigos não cria opção ativa")
equal(Config.get("mam_storage_query"), nil, "consulta manual de deposito nao configurada")
equal(Config.get("mam_station_storage"), nil, "integracao com bancada ainda nao configurada")
equal(Config.on("mam_batch"), false, "on respeita zero")
Config.set("mam_batch", 1)
equal(Config.on("mam_batch"), true, "on respeita um")
equal(Config.int("mam_batch_time"), 25, "int retorna valor inteiro")
equal(Config.initialised(), true, "modulo marca inicializacao")

print(("PASS: %d verificacoes de configuracao"):format(passed))
