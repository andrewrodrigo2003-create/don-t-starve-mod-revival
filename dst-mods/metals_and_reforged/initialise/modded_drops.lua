-- Fontes de minerio do mod: declaracao unica, aditiva e desativavel por fonte.
--
-- Antes (v2.9.3): scripts/prefabs/newrocks.lua reescrevia 18 loot tables vanilla
-- por inteiro, modmain.lua trocava o loot do marbleshrub e do shark, e
-- initialise/modded_marbletrees.lua empilhava AddChanceLoot solto. Tres caminhos
-- diferentes para a mesma coisa, nenhum deles desativavel, e o primeiro
-- sobrescrevia o balanceamento de quem carregasse antes.
--
-- Agora: tudo passa por mam/loot_guard.lua. As chances abaixo sao COPIA EXATA das
-- que o v2.9.3 declarava -- nada foi reequilibrado (briefing, secao 2). O que mudou foi
-- o mecanismo: em vez de substituir a table, o roll entra na entidade, somado ao
-- que o jogo ou outro mod ja' tiver posto la'.
--
-- Regra: no modo aditivo so' entram MATERIAIS NOSSOS. Reduzir rocks/flint/
-- goldnugget vanilla, como o v2.9.3 fazia dentro da mesma reescrita, e' opcao do
-- jogador em "Ore drop mode > Rewrite", nao o padrao.

local require = GLOBAL.require
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")
local MAMLootGuard = require("mam/loot_guard")

MAMLootGuard.Init(AddPrefabPostInit)

----------------------------------------------------------------------
-- Rochas da superficie e da lua
-- v2.9.3: newrocks.lua:51 (rock2), :63 (rock_moon), :75 (rock_moon_shell)
-- vanilla: prefabs/rocks.lua:73, :108, :118 -- prefabs de mesmo nome
----------------------------------------------------------------------
MAMLootGuard.Declare("rock2", "boulders", {
    { "gold_dust", 0.75 },
    { "gold_dust", 1.00 },
})

MAMLootGuard.Declare("rock_moon", "boulders", {
    { "iron_ore", 0.50 },
    { "iron_ore", 0.50 },
})

MAMLootGuard.Declare("rock_moon_shell", "boulders", {
    { "iron_dust", 0.75 },
    { "iron_ore",  0.50 },
})

----------------------------------------------------------------------
-- Estalagmites e estalactites (cavernas)
-- v2.9.3: newrocks.lua:87 (full_rock), :106 (med_rock), :120 (low_rock),
--         :132/:150/:166 (stalagmite_tall_*)
-- vanilla: prefabs/stalagmite.lua:18/32/42 e prefabs/stalagmite_tall.lua:18/31/41
-- Cada table atende DOIS prefabs: o nome da fase e o nome "aleatorio" que o mapa
-- usa (stalagmite.lua:151-154, stalagmite_tall.lua:152-155).
----------------------------------------------------------------------
MAMLootGuard.Declare({ "stalagmite", "stalagmite_full" }, "stalagmites", {
    { "gold_dust",      0.75 },
    { "copper_ore",     0.50 },
    { "copper_ore",     0.50 },
    { "copper_dust",    1.00 },
    { "copper_dust",    0.50 },
    { "copper_ore",     0.50 },
    { "copper_dust",    1.00 },
    { "bluegem_shard",  0.25 },
    { "redgem_shard",   0.25 },
})

MAMLootGuard.Declare("stalagmite_med", "stalagmites", {
    { "copper_dust", 1.00 },
    { "copper_dust", 0.75 },
    { "gold_dust",   0.50 },
    { "copper_ore",  0.75 },
    { "copper_ore",  0.50 },
    { "copper_ore",  0.35 },
})

MAMLootGuard.Declare("stalagmite_low", "stalagmites", {
    { "copper_dust", 1.00 },
    { "gold_dust",   0.25 },
    { "copper_dust", 0.75 },
    { "copper_ore",  0.25 },
    { "copper_ore",  0.25 },
})

MAMLootGuard.Declare({ "stalagmite_tall", "stalagmite_tall_full" }, "stalagmites", {
    { "gold_dust",     1.00 },
    { "gold_dust",     0.35 },
    { "copper_dust",   1.00 },
    { "redgem_shard",  0.05 },
    { "copper_dust",   1.00 },
    { "copper_ore",    0.50 },
    { "copper_ore",    0.25 },
    { "copper_ore",    0.25 },
})

MAMLootGuard.Declare("stalagmite_tall_med", "stalagmites", {
    { "copper_ore",  0.60 },
    { "copper_ore",  0.25 },
    { "gold_dust",   1.00 },
    { "copper_dust", 1.00 },
    { "copper_dust", 0.50 },
    { "copper_dust", 0.50 },
    { "copper_ore",  0.50 },
})

MAMLootGuard.Declare("stalagmite_tall_low", "stalagmites", {
    { "gold_dust",   1.00 },
    { "copper_dust", 0.80 },
    { "copper_dust", 0.50 },
    { "gold_ore",    0.05 },
    { "copper_ore",  0.50 },
    { "copper_ore",  0.25 },
})

----------------------------------------------------------------------
-- Ruinas: pecas de xadrez e sucata
-- v2.9.3: newrocks.lua:180 (chess_junk), :193/:201 (knight), :211/:220 (rook),
--         :230/:242 (bishop)
-- vanilla: chessjunk.lua:27, knight.lua:29/35, rook.lua:31/37, bishop.lua:33/40
-- Criatura perigosa da ruina da' material melhor que a rocha da superficie:
-- knight/rook/bishop soltam lingote, a sucata da' po e fragmento de gema.
----------------------------------------------------------------------
MAMLootGuard.Declare({ "chessjunk", "chessjunk1", "chessjunk2", "chessjunk3" }, "chess", {
    { "redgem_shard",   0.50 },
    { "greengem_shard", 0.25 },
    { "bluegem_shard",  0.50 },
    { "copper_dust",    0.50 },
})

MAMLootGuard.Declare("knight", "chess", {
    { "copper_ore", 0.50 },
    { "copper_ore", 1.00 },
})

MAMLootGuard.Declare("knight_nightmare", "chess", {
    { "copper_ore", 0.50 },
    { "copper_ore", 0.50 },
    { "copper_ore", 1.00 },
})

MAMLootGuard.Declare("rook", "chess", {
    { "copper_ingot", 0.75 },
    { "copper_ingot", 0.75 },
    { "iron_ingot",   1.00 },
})

MAMLootGuard.Declare("rook_nightmare", "chess", {
    { "copper_ingot", 0.75 },
    { "copper_ingot", 0.75 },
    { "iron_ingot",   1.00 },
})

MAMLootGuard.Declare("bishop", "chess", {
    { "bluegem_shard", 1.00 },
    { "redgem_shard",  1.00 },
    { "bluegem_shard", 0.50 },
    { "redgem_shard",  0.50 },
    { "copper_ingot",  0.75 },
    { "iron_ingot",    1.00 },
})

MAMLootGuard.Declare("bishop_nightmare", "chess", {
    { "copper_ingot",    0.50 },
    { "iron_ingot",      1.00 },
    { "purplegem_shard", 1.00 },
    { "purplegem_shard", 0.75 },
    { "purplegem_shard", 0.50 },
    { "purplegem_shard", 0.25 },
})

----------------------------------------------------------------------
-- Caes elementais -- CEDE ao Uncompromising Mode
-- v2.9.3: newrocks.lua:255 (hound_fire), :268 (hound_cold)
-- UM Beta: postinit/prefabs/firehound.lua:4-12 e icehound.lua:4-12 reescrevem as
-- mesmas tables dentro de AddSimPostInit e passam a dar redgem/bluegem 0.3.
-- Nossos 4 rolls de fragmento (1.0+0.75+0.5+0.25) valeriam mais que a gema do UM
-- na mesma criatura: duas fontes do mesmo material. Por isso o padrao e' "Auto",
-- que desliga esta fonte quando o UM esta' ativo. "Always" forca; sem UM, "Auto"
-- se comporta exatamente como o original.
----------------------------------------------------------------------
MAMLootGuard.Declare("firehound", "hounds", {
    { "redgem_shard", 1.00 },
    { "redgem_shard", 0.75 },
    { "redgem_shard", 0.50 },
    { "redgem_shard", 0.25 },
}, { skip_if_um = true })

MAMLootGuard.Declare("icehound", "hounds", {
    { "bluegem_shard", 1.00 },
    { "bluegem_shard", 0.75 },
    { "bluegem_shard", 0.50 },
    { "bluegem_shard", 0.25 },
}, { skip_if_um = true })

----------------------------------------------------------------------
-- Arvore de marmore NATURAL
-- v2.9.3: initialise/modded_marbletrees.lua:20-29, ja' aditivo, com rolls
-- repetidos do mesmo item. Valores preservados um a um.
--
-- De proposito NAO cobre marbletree_1..4: e' nelas que a semente plantada cresce
-- (scripts/prefabs/marbleseed.lua:15), e o mapa so' gera "marbletree"
-- (map/rooms/forest/chess.lua:22/48, map/layouts.lua:620). Estender o drop as
-- arvores plantadas criaria fonte renovavel de minerio -- o briefing proibe (secao 4).
----------------------------------------------------------------------
MAMLootGuard.Declare("marbletree", "marbletree", {
    { "marbleseed", 1.0 },
    { "marbleseed", 0.1 },
    { "nitre",      0.75 },
    { "rocks",      1.0 },
    { "goldnugget", 0.25 },
    { "flint",      1.0 },
    { "gold_dust",  1.0 },
    { "gold_dust",  0.75 },
    { "gold_dust",  0.75 },
    { "copper_ore", 1.0 },
}, { apply_in_rewrite = true })

----------------------------------------------------------------------
-- Tubarao -- material proprio do mod, sem conflito
-- v2.9.3: modmain.lua:449-454. O UM Beta acrescenta rockjawleather ao mesmo
-- prefab (postinit/prefabs/shark.lua:9) por AddChanceLoot: os dois sao aditivos.
----------------------------------------------------------------------
MAMLootGuard.Declare("shark", "shark", {
    { "sharkscale", 1.00 },
    { "sharkscale", 0.05 },
}, { apply_in_rewrite = true })

----------------------------------------------------------------------
-- Arbusto de marmore
-- v2.9.3: modmain.lua:408-434 trocava o lootsetupfn inteiro por listas fixas.
-- vanilla: prefabs/marbleshrub.lua:107-109 sorteia o loot por estagio
-- (statedata.loot, :30/:40/:50). Trocar a funcao jogava fora o sorteio vanilla e
-- o que outro mod tiver posto no lugar.
--
-- Modo aditivo: encadeia a funcao viva e acrescenta so' o nosso iron_ore, na
-- quantidade que o v2.9.3 dava por estagio (normal 1, tall 2). A contagem conta
-- o iron_ore que JA' esta na lista, entao repetir a chamada nao acumula e um
-- iron_ore posto por outro mod nao e' duplicado.
----------------------------------------------------------------------
local SHRUB_IRON_BY_STAGE = { [2] = 1, [3] = 2 }

local function shrub_additive(inst)
    local lootdropper = inst.components.lootdropper
    if lootdropper == nil then
        return
    end

    local previous = lootdropper.lootsetupfn
    lootdropper:SetLootSetupFn(function(dropper)
        if previous ~= nil then
            previous(dropper)
        end

        local loot = dropper.loot
        if loot == nil then
            -- Outro mod trocou o mecanismo (chanceloot/randomloot): nao ha lista
            -- para somar, e criar uma aqui passaria por cima do dele.
            return
        end

        local stage = inst.components.growable ~= nil and inst.components.growable.stage or 1
        local wanted = SHRUB_IRON_BY_STAGE[stage] or 0
        if wanted <= 0 then
            return
        end

        local present = 0
        for _, item in ipairs(loot) do
            if item == "iron_ore" then
                present = present + 1
            end
        end
        for _ = present + 1, wanted do
            table.insert(loot, "iron_ore")
        end
    end)
end

-- Listas do v2.9.3, usadas apenas no modo "Rewrite" (comportamento original).
local function shrub_original(inst)
    local shrubshort = { "rocks", "marblebean" }
    local shrubnormal = { "marble", "iron_ore", "rocks", "rocks", "marblebean" }
    local shrubtall = { "marble", "marble", "iron_ore", "iron_ore", "rocks", "rocks", "rocks", "marblebean" }

    if inst.components.lootdropper == nil then
        inst:AddComponent("lootdropper")
    end

    inst.components.lootdropper:SetLootSetupFn(function(lootdropper)
        local stage = inst.components.growable ~= nil and inst.components.growable.stage or 1
        if stage == 1 then
            lootdropper:SetLoot(shrubshort)
        elseif stage == 2 then
            lootdropper:SetLoot(shrubnormal)
        else
            lootdropper:SetLoot(shrubtall)
        end
    end)
end

local function marble_shrub(inst)
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end
    if not MAMConfig.on("mam_extra_drops") or not MAMConfig.on("mam_drop_marbleshrub") then
        return
    end

    if MAMConfig.int("mam_drops_mode", 1) == 2 then
        shrub_original(inst)
    else
        shrub_additive(inst)
    end
end

for _, name in ipairs({ "marbleshrub", "marbleshrub_short", "marbleshrub_normal", "marbleshrub_tall" }) do
    AddPrefabPostInit(name, MAMLog.Guarded("modded_drops.marbleshrub", marble_shrub))
end

AddSimPostInit(function()
    MAMLog.Try("modded_drops.dump", MAMLootGuard.dump)
end)