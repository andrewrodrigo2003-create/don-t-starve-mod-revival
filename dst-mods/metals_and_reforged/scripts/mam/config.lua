-- Metals and More - Reworked & Fixed
-- Leitura centralizada das configuracoes do mod, com defaults seguros.
--
-- Por que existe: GetModConfigData() espalhado por 15 arquivos diferentes nao
-- tem default, nao e validado e nao pode ser sincronizado com o servidor.
-- Aqui cada opcao tem um default declarado, e o modmain injeta os valores uma
-- unica vez antes de qualquer prefab ou componente ser carregado.
--
-- Regra do projeto: NENHUM script deve chamar GetModConfigData diretamente.
-- Use MAMConfig.get("chave").

local MAMConfig = {}

--- Defaults canonicos. Se uma chave nao existir aqui, get() devolve nil e o
--- chamador deve tratar; isso e intencional para pegar opcao sem default.
local DEFAULTS = {
    -- Nucleo de fundicao (Etapa 1)
    mam_batch          = 1,    -- 0 = 1 mineral por vez (original), 1 = lote
    mam_batch_time     = 25,   -- % de tempo extra por unidade adicional do lote
    mam_forecast       = 2,    -- 0 = off, 1 = so resultado certo, 2 = mostra alternativas
    mam_leftovers      = 1,    -- 0 = destroi sobra (original), 1 = devolve ao jogador
    mam_batch_cap      = 10,   -- teto de unidades por operacao

    -- Receitas e drops (Etapa 2)
    mam_recipe_overrides = 1,  -- vanilla ingredient overrides
    mam_third_party_recipe_integration = 1,
    mam_allow_third_party_drop_overrides = 0,
    mam_extra_drops      = 1,  -- 0 = nenhum drop extra de rochas/criaturas
    mam_drops_mode       = 1,  -- 1 = aditivo por entidade, 2 = reescreve as tables (original)
    -- 0 = chances do v2.9.3, inclusive rolls repetidos que somam mais de 1.
    -- Ligado, escala os rolls para a expectativa por item e por fonte ficar em 1.
    mam_drops_normalise  = 0,
    mam_drop_boulders    = 1,  -- rock2, rock_moon, rock_moon_shell
    mam_drop_stalagmites = 1,  -- estalagmites/estalactites, todas as fases
    mam_drop_chess       = 1,  -- knight, rook, bishop, variantes nightmare e chessjunk
    mam_drop_hounds      = 1,  -- 1 = auto (cede ao UM), 2 = sempre, 0 = nunca
    mam_drop_marbletree  = 1,  -- arvore de marmore natural (nao a plantada)
    mam_drop_marbleshrub = 1,  -- iron_ore do arbusto, por estagio
    mam_drop_shark = 1,  -- sharkscale
    mam_drop_rocky = 1, -- wild Rockys only; player-following Rockies are excluded
    mam_drop_rubble = 1, -- cave rubble mined by players
    mam_drop_ancient_statues = 1, -- ancient Ruins statues mined by players
    mam_drop_boulders_chance = 100,
    mam_drop_stalagmites_chance = 100,
    mam_drop_chess_chance = 100,
    mam_drop_hounds_chance = 100,
    mam_drop_marbletree_chance = 100,
    mam_drop_shark_chance = 100,
    mam_drop_rocky_chance = 100,
    mam_drop_rubble_chance = 100,
    mam_drop_ancient_statues_chance = 100,
    mam_drop_marbleshrub_quantity = 100,
    mam_robot_smelting   = 0,  -- collector robot may feed nearby smelters from compatible containers
    mam_language         = "ptbr", -- ptbr = Brazilian Portuguese, en = English

}

-- Apenas valores que existem nas configuration_options do modinfo.lua.
-- A validacao tambem protege os overrides sincronizados pelo servidor: valores
-- ausentes, antigos ou malformados voltam ao default seguro, sem alterar os
-- defaults ou o balanceamento de uma configuracao valida.
local ALLOWED = {
    mam_batch             = { [0] = true, [1] = true },
    mam_batch_time        = { [0] = true, [25] = true, [50] = true, [75] = true },
    mam_forecast          = { [0] = true, [1] = true, [2] = true },
    mam_leftovers         = { [0] = true, [1] = true },
    mam_batch_cap         = { [4] = true, [10] = true, [20] = true },
    mam_recipe_overrides  = { [0] = true, [1] = true, [2] = true },
    mam_third_party_recipe_integration = { [0] = true, [1] = true },
    mam_allow_third_party_drop_overrides = { [0] = true, [1] = true },
    mam_extra_drops       = { [0] = true, [1] = true },
    mam_drops_mode        = { [1] = true, [2] = true },
    mam_drops_normalise   = { [0] = true, [1] = true },
    mam_drop_boulders     = { [0] = true, [1] = true },
    mam_drop_stalagmites  = { [0] = true, [1] = true },
    mam_drop_chess        = { [0] = true, [1] = true },
    mam_drop_hounds       = { [0] = true, [1] = true, [2] = true },
    mam_drop_marbletree   = { [0] = true, [1] = true },
    mam_drop_marbleshrub  = { [0] = true, [1] = true },
    mam_drop_shark        = { [0] = true, [1] = true },
    mam_drop_rocky        = { [0] = true, [1] = true },
    mam_drop_rubble       = { [0] = true, [1] = true },
    mam_drop_ancient_statues = { [0] = true, [1] = true },
    mam_drop_boulders_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_stalagmites_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_chess_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_hounds_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_marbletree_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_shark_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_rocky_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_rubble_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_ancient_statues_chance = { [25] = true, [50] = true, [75] = true, [100] = true, [125] = true, [150] = true },
    mam_drop_marbleshrub_quantity = { [0] = true, [100] = true, [200] = true, [300] = true },
    mam_robot_smelting    = { [0] = true, [1] = true },
    mam_language          = { ptbr = true, en = true },
}

local values = {}
local initialised = false

local function read(key, getter)
    local ok, v = pcall(getter, key)
    if not ok then
        return nil
    end
    return v
end

local function is_allowed(key, value)
    local allowed = ALLOWED[key]
    return allowed ~= nil and allowed[value] == true
end

--- Chamado pelo modmain logo no inicio. `getter` e GetModConfigData.
--- `overrides` permite que o servidor publique seus valores para o cliente.
function MAMConfig.Init(getter, overrides)
    if type(getter) ~= "function" then
        getter = function() return nil end
    end

    for key, default in pairs(DEFAULTS) do
        local v = read(key, getter)
        values[key] = is_allowed(key, v) and v or default
    end

    if type(overrides) == "table" then
        for key, v in pairs(overrides) do
            if DEFAULTS[key] ~= nil and is_allowed(key, v) then
                values[key] = v
            end
        end
    end

    initialised = true
end

function MAMConfig.get(key, fallback)
    local v = values[key]
    if v == nil then
        v = DEFAULTS[key]
    end
    if v == nil then
        return fallback
    end
    return v
end

function MAMConfig.set(key, value)
    if DEFAULTS[key] ~= nil and is_allowed(key, value) then
        values[key] = value
    end
end

function MAMConfig.on(key)
    return (MAMConfig.get(key, 0) or 0) > 0
end

--- Numeros vindos do modinfo sao sempre floats; normaliza para inteiro.
function MAMConfig.int(key, fallback)
    local v = MAMConfig.get(key, fallback)
    if type(v) ~= "number" then
        return fallback or 0
    end
    return math.floor(v + 0.5)
end

function MAMConfig.dump()
    local out = {}
    for key, default in pairs(DEFAULTS) do
        out[key] = values[key] ~= nil and values[key] or default
    end
    return out
end

MAMConfig.initialised = function()
    return initialised
end

return MAMConfig
