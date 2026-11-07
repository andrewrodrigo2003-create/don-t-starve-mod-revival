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
    mam_recipe_overrides = 1,  -- 0 = nao reescreve receitas vanilla, 1 = so' intactas, 2 = sempre
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
    mam_drop_shark       = 1,  -- sharkscale

    -- Armazenamento (Etapas 3/4)
    mam_metalschest      = 1,
    mam_storage_query    = 1,
    mam_station_storage  = 1,
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

--- Chamado pelo modmain logo no inicio. `getter` e GetModConfigData.
--- `overrides` permite que o servidor publique seus valores para o cliente.
function MAMConfig.Init(getter, overrides)
    if type(getter) ~= "function" then
        getter = function() return nil end
    end

    for key, default in pairs(DEFAULTS) do
        local v = read(key, getter)
        if v == nil then
            v = default
        end
        values[key] = v
    end

    if type(overrides) == "table" then
        for key, v in pairs(overrides) do
            if DEFAULTS[key] ~= nil and v ~= nil then
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
    if DEFAULTS[key] ~= nil and value ~= nil then
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
