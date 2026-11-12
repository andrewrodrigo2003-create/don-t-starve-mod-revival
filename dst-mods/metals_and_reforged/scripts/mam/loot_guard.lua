-- Guarda de drops extras de minerio.
--
-- POR QUE ISTO EXISTE
-- O v2.9.3 reescrevia 18 loot tables VANILLA por inteiro, com SetSharedLootTable
-- em scripts/prefabs/newrocks.lua. SetSharedLootTable e' apenas
-- LootTables[name] = table (components/lootdropper.lua:22-24): quem escreve por
-- ultimo vence, em silencio, e o balanceamento do outro mod desaparece.
--
-- Medido contra os mods que o briefing coloca como prioridade:
--   * "My Moar Metals" v422 reescreve rock2, rock_moon, full_rock, med_rock,
--     low_rock e as stalagmites DENTRO de AddSimPostInit (modmain.lua:330-456),
--     ou seja, sempre depois da nossa escrita na carga do prefab.
--   * Uncompromising Mode Beta reescreve hound_fire e hound_cold tambem dentro de
--     AddSimPostInit (postinit/prefabs/firehound.lua:4-12, icehound.lua:4-12) e
--     passa a dar redgem/bluegem 0.3. Somar os nossos gem shards por cima criaria
--     uma segunda fonte de gema na mesma criatura -- exatamente o que o briefing
--     proibe ("evitar duplicar drops que outro mod ja adicionou").
--
-- COMO RESOLVEMOS
-- Drop extra entra por inst.components.lootdropper:AddChanceLoot, no
-- AddPrefabPostInit da entidade. GenerateLoot rola chanceloot e chanceloottable
-- em passos separados (components/lootdropper.lua:151-222), entao o nosso roll e'
-- aditivo e imune a troca de table: ninguem e' sobrescrito, e ninguem nos apaga.
-- A entidade nasce muito depois de qualquer AddSimPostInit, o que tambem resolve
-- a ordem de carga entre mods.
--
-- Regra de balanceamento: no modo aditivo so' acrescentamos MATERIAIS NOSSOS
-- (minerio, po, lingote, gem shard). As chances sao as do v2.9.3, copiadas sem
-- reequilibrar. O que o v2.9.3 fazia a mais -- reduzir rocks/flint/goldnugget da
-- table vanilla -- fica disponivel no modo "rewrite", que e' o comportamento
-- original e assume o risco de sobrescrever outro mod.

local GLOBAL = rawget(_G, "GLOBAL") or _G
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")

local M = {}

local add_prefab_post_init = nil
local sources = {}   -- [prefab] = { source, ... }
local hooked = {}

M.declared = {}      -- [key] = { source = source, prefabs = n }
M.stats = { applied = 0, skipped = {} }

--- AddPrefabPostInit so' existe no ambiente do modmain; quem roda por require()
--- precisa recebe-lo injetado (mesmo contrato de mam/recipe_guard.lua).
function M.Init(fn)
    add_prefab_post_init = fn
end

--- Uncompromising Mode publica GLOBAL.UMCommonFns no modmain dele (modmain.lua:22).
--- Consultado tarde, na construcao da entidade: a essa altura todos os modmain ja
--- rodaram, qualquer que seja a ordem de carga. Sem o UM, devolve false e nada muda.
function M.HasUncompromising()
    return GLOBAL.UMCommonFns ~= nil
end

--- Opcional: teto de 1.0 na probabilidade AGREGADA por item e por fonte.
--- O v2.9.3 empilha rolls do mesmo item (gold_dust 1.0 + 0.75 + 0.75 na marbletree,
--- 2.5 unidades esperadas). Escalar preserva o peso relativo de cada roll e corta
--- a expectativa para 1 -- e' a opcao "sem farm facil", desligada por padrao para
--- nao mudar o balanceamento original sem o jogador pedir.
local function prepare(entries, scale)
    scale = type(scale) == "number" and math.max(0, scale) or 1
    local scaled = {}
    for i, entry in ipairs(entries) do
        scaled[i] = { entry[1], math.min(1, math.max(0, entry[2] * scale)) }
    end
    entries = scaled

    if not MAMConfig.on("mam_drops_normalise") then
        return entries
    end

    local totals = {}
    for _, entry in ipairs(entries) do
        totals[entry[1]] = (totals[entry[1]] or 0) + entry[2]
    end

    local out = {}
    for i, entry in ipairs(entries) do
        local total = totals[entry[1]]
        out[i] = { entry[1], total > 1 and entry[2] / total or entry[2] }
    end
    return out
end

-- Compartilhado com newrocks.lua para que o modo Rewrite respeite a mesma
-- opcao de normalizacao do modo aditivo.
M.PrepareEntries = prepare

local function state(source)
    if not MAMConfig.on("mam_extra_drops") then
        return false, "master-off"
    end

    local mode = MAMConfig.int("mam_drops_mode", 1)
    if mode == 2 and not MAMConfig.on("mam_allow_third_party_drop_overrides") then
        mode = 1 -- fallback aditivo: nunca substituir loot tables compartilhadas sem opt-in
    end
    local value = MAMConfig.int("mam_drop_" .. source.key, 1)
    if value <= 0 then
        return false, "source-off"
    end
    if mode == 0 then
        return false, "disabled"
    end

    if mode == 2 then
        -- A maioria das fontes usa SetSharedLootTable no modo Rewrite.
        -- Algumas fontes historicas eram AddChanceLoot por entidade (arvore
        -- de marmore/tubarao), e continuam precisando desse caminho.
        -- Hounds: no modo Rewrite, Auto sem UM usa a tabela original; com UM,
        -- Auto cede e Always soma nossos fragmentos sem apagar as gemas do UM.
        local rewrite_additive = source.apply_in_rewrite
            or (source.skip_if_um and value == 2 and M.HasUncompromising())
        if not rewrite_additive then
            return false, "rewrite-mode"
        end
    end

    if source.skip_if_um and value == 1 and M.HasUncompromising() then
        return false, "um-present"
    end
    return true, "on"
end

local function apply(name, inst)
    -- TheWorld pode nao existir quando o jogo instancia um prefab fora do mundo
    -- (preview/scrapbook). Sem mundo nao ha' o que dropar.
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end

    local lootdropper = inst.components.lootdropper
    if lootdropper == nil then
        MAMLog.WarnOnce("loot_guard.nolootdropper." .. name,
            "'%s' nao tem lootdropper -- fonte de drop extra ignorada.", name)
        return
    end

    for _, source in ipairs(sources[name] or {}) do
        local enabled, reason = state(source)
        if enabled then
            for _, entry in ipairs(source.entries) do
                lootdropper:AddChanceLoot(entry[1], entry[2])
                M.stats.applied = M.stats.applied + 1
            end
        else
            M.stats.skipped[reason] = (M.stats.skipped[reason] or 0) + 1
        end
    end
end

--- Declara uma fonte de drop extra, desativavel pela opcao mam_drop_<key>.
-- @param prefabs  nome do prefab, ou lista de nomes que compartilham a mesma fonte
-- @param key      identificador da opcao no modinfo (sem o prefixo mam_drop_)
-- @param entries  { {item, chance}, ... } -- chances exatamente como no v2.9.3
-- @param opts     { skip_if_um = true } cede quando o UM ja' reequilibrou a fonte
function M.Declare(prefabs, key, entries, opts)
    if add_prefab_post_init == nil then
        MAMLog.Error("loot_guard.Declare('%s') chamado sem MAMLootGuard.Init(AddPrefabPostInit)",
            tostring(key))
        return
    end

    if type(prefabs) == "string" then
        prefabs = { prefabs }
    end

    local chance_scale = MAMConfig.int("mam_drop_" .. key .. "_chance", 100) / 100
    local source = {
        key = key,
        entries = prepare(entries, chance_scale),
        skip_if_um = opts ~= nil and opts.skip_if_um == true,
        apply_in_rewrite = opts ~= nil and opts.apply_in_rewrite == true,
    }

    local record = M.declared[key]
    if record == nil then
        record = { source = source, prefabs = 0 }
        M.declared[key] = record
    end

    for _, name in ipairs(prefabs) do
        record.prefabs = record.prefabs + 1
        if sources[name] == nil then
            sources[name] = {}
        end
        table.insert(sources[name], source)

        if not hooked[name] then
            hooked[name] = true
            add_prefab_post_init(name, MAMLog.Guarded("loot_guard." .. name, function(inst)
                apply(name, inst)
            end))
        end
    end
end

--- Linha de diagnostico: o que foi declarado, o que esta ligado e por que nao esta.
function M.dump()
    local parts = {}
    for key, record in pairs(M.declared) do
        local _, reason = state(record.source)
        table.insert(parts, ("%s=%s(%dp/%dr)"):format(
            key, reason, record.prefabs, #record.source.entries))
    end
    table.sort(parts)

    local skipped = {}
    for reason, count in pairs(M.stats.skipped) do
        table.insert(skipped, reason .. "=" .. count)
    end
    table.sort(skipped)

    print(("[MAM][loot_guard] modo=%d normalise=%d UM=%s | %s | rolls aplicados=%d pulados: %s")
        :format(MAMConfig.int("mam_drops_mode", 1),
            MAMConfig.on("mam_drops_normalise") and 1 or 0,
            tostring(M.HasUncompromising()),
            table.concat(parts, " "),
            M.stats.applied,
            table.concat(skipped, ", ")))
end

return M