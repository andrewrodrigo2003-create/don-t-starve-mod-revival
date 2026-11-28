local rock1_assets =
{
    Asset("ANIM", "anim/ruins_artichoke.zip"),
	
    Asset("IMAGE", "images/mapicons/spikyrock.tex"), 
	Asset("ATLAS", "images/mapicons/spikyrock.xml"),
	
    Asset("IMAGE", "images/mapicons/ironrock.tex"), 
	Asset("ATLAS", "images/mapicons/ironrock.xml"),
}

local rock3_assets =
{
    Asset("ANIM", "anim/rock_basalt.zip"),
}

local prefabs =
{
    "rocks",
    "nitre",
    "flint",
    "goldnugget",
    "moonrocknugget",
	"moonrockseed",
    "rock_break_fx",
    "collapse_small",
}

SetSharedLootTable( 'spikyrock',
{
	{'copper_ore', 		1.00},
	{'copper_ore', 		1.00},
	{'copper_ore', 		1.00},
	{'copper_dust', 	1.00},
	{'copper_ore', 		1.00},
	{'copper_dust', 	1.00},
})

SetSharedLootTable( 'ironrock',
{
	{'rocks',           0.75},
	{'rocks',           0.75},
	{'rocks',           0.75},
	{'iron_ore', 		1.00},
	{'iron_ore', 		0.75},
	{'iron_ore', 		0.25},
	{'iron_ore',		0.50},
    {'flint',      		0.20},
})

-- As 18 tables abaixo sao VANILLA (rock2, rock_moon, ... hound_cold). Reescreve-las
-- por inteiro e' o comportamento original do v2.9.3: SetSharedLootTable e' so'
-- LootTables[name] = table (components/lootdropper.lua:22-24), entao o ultimo mod
-- que escreve vence em silencio. Moar Metals v422 e UM Beta reescrevem varias
-- destas mesmas tables dentro de AddSimPostInit, sempre depois desta carga.
--
-- No modo padrao (aditivo) este bloco NAO roda: o minerio entra por entidade em
-- initialise/modded_drops.lua, somado ao que o jogo ou outro mod ja' definiu.
-- "Rewrite" e' o escape para quem quer o comportamento original de volta.
--
-- A indentacao do bloco foi mantida como no v2.9.3 para o diff contra
-- .reference/metals-and-more-v2.9.3-original continuar legivel.
local MAMConfig = require("mam/config")
local MAMLootGuard = require("mam/loot_guard")

local function set_rewrite_table(name, entries, source_key)
    SetSharedLootTable(name, MAMLootGuard.PrepareEntries(entries, source_key))
end

if MAMConfig.on("mam_extra_drops")
    and MAMConfig.int("mam_drops_mode", 1) == 2
    and MAMConfig.on("mam_allow_third_party_drop_overrides") then
    if MAMConfig.on("mam_drop_boulders") then
        set_rewrite_table('rock2', {
            {'rocks',       1.00},
            {'rocks',       1.00},
            {'rocks',       0.75},
            {'goldnugget', 	0.50},
        	{'gold_dust', 	0.75},
        	{'gold_dust', 	1.00},
        	{'goldnugget', 	0.90},
            {'flint',       0.75},
        }, "boulders")

        set_rewrite_table('rock_moon', {
            {'rocks',           1.00},
        	{'rocks',           0.75},
            {'moonrocknugget',  1.00},
            {'moonrocknugget',  1.00},
            {'moonrocknugget',  0.60},
            {'moonrocknugget',  0.30},
        	{'iron_ore',		0.50},
        	{'iron_ore',		0.50},
        }, "boulders")

        set_rewrite_table('rock_moon_shell', {
            {'rocks',           1.00},
            {'rocks',           0.75},
            {'moonrocknugget',  1.00},
            {'moonrocknugget',  1.00},
            {'moonrocknugget',  1.00},
            {'moonrocknugget',  0.30},
        	{'iron_dust',		0.75},
        	{'iron_ore',		0.50},
        }, "boulders")
    end

    if MAMConfig.on("mam_drop_stalagmites") then
        set_rewrite_table('full_rock', {
            {'rocks',       	1.00},
            {'rocks',       	1.00},
            {'rocks',       	1.00},
            {'flint',       	1.00},
            {'fossil_piece',	0.10},
            {'gold_dust', 		0.75},
        	{'goldnugget', 		0.25},
        	{'copper_ore',    	0.50},
        	{'copper_ore',    	0.50},
        	{'copper_dust',    	1.00},
        	{'copper_dust',    	0.50},
        	{'copper_ore',    	0.50},
        	{'copper_dust',    	1.00},
            {'bluegem_shard',	0.25},
            {'redgem_shard',    0.25},
        }, "stalagmites")

        set_rewrite_table('med_rock', {
            {'rocks',       1.00},
            {'rocks',       1.00},
            {'copper_dust', 1.00},
        	{'copper_dust', 0.75},
            {'gold_dust',  	0.50},
            {'fossil_piece',0.10},
            {'flint',       0.60},
        	{'copper_ore',  0.75},
        	{'copper_ore',  0.50},
        	{'copper_ore', 	0.35},
        }, "stalagmites")

        set_rewrite_table('low_rock', {
            {'rocks',       1.00},
            {'copper_dust', 1.00},
            {'gold_dust',  	0.25},
            {'fossil_piece',0.10},
            {'flint',       0.30},
        	{'copper_dust', 0.75},
        	{'copper_ore', 	0.25},
        	{'copper_ore', 	0.25},
        }, "stalagmites")

        set_rewrite_table('stalagmite_tall_full_rock', {
            {'rocks',       	1.00},
            {'rocks',       	1.00},
            {'gold_dust',  		1.00},
            {'flint',       	1.00},
            {'fossil_piece',	0.10},
            {'gold_dust',  		0.35},
            {'copper_dust', 	1.00},
            {'redgem_shard',    0.05},
            {'log',         	0.05},
        	{'goldnugget', 		0.25},
        	{'copper_dust',  	1.00},
        	{'copper_ore',    	0.50},
        	{'copper_ore', 		0.25},
        	{'copper_ore', 		0.25},
        }, "stalagmites")

        set_rewrite_table('stalagmite_tall_med_rock', {
            {'rocks',       1.00},
            {'rocks',       1.00},
            {'flint',       1.00},
            {'fossil_piece',0.10},
            {'goldnugget',  0.15},
            {'copper_ore',  0.60},
        	{'copper_ore', 	0.25},
        	{'gold_dust',  	1.00},
        	{'copper_dust', 1.00},
        	{'copper_dust', 0.50},
        	{'copper_dust', 0.50},
        	{'copper_ore',  0.50},
        }, "stalagmites")

        set_rewrite_table('stalagmite_tall_low_rock', {
            {'rocks',       1.00},
            {'flint',       1.00},
            {'fossil_piece',0.10},
            {'gold_dust', 	1.00},
            {'flint',       0.30},
            {'copper_dust', 0.80},
        	{'copper_dust', 0.50},
        	{'gold_ore', 	0.05},
        	{'copper_ore',  0.50},
        	{'copper_ore', 	0.25},
        }, "stalagmites")
    end

    if MAMConfig.on("mam_drop_chess") then
        if MAMConfig.on("mam_drop_chessjunk") then
            set_rewrite_table("chess_junk", {
                {'trinket_6', 1.00}, {'trinket_6', 0.55}, {'trinket_1', 0.25},
                {'gears', 0.25}, {'redgem_shard', 0.50}, {"greengem_shard", 0.25},
                {"bluegem_shard", 0.50}, {"thulecite", 0.01}, {'copper_dust', 0.50},
            }, "chessjunk")
        end
        if MAMConfig.on("mam_drop_knight") then
            set_rewrite_table('knight', {
                {'gears', 1.00}, {'gears', 1.00},
                {'copper_ore', 0.50}, {'copper_ore', 1.00},
            }, "knight")
            set_rewrite_table('knight_nightmare', {
                {'gears', 1.00}, {'nightmarefuel', 0.60},
                {'thulecite_pieces', 0.50}, {'copper_ore', 0.50},
                {'copper_ore', 0.50}, {'copper_ore', 1.00},
            }, "knight")
        end
        if MAMConfig.on("mam_drop_rook") then
            set_rewrite_table('rook', {
                {'gears', 1.00}, {'gears', 1.00},
                {'copper_ingot', 0.75}, {'copper_ingot', 0.75},
                {'iron_ingot', 1.00},
            }, "rook")
            set_rewrite_table('rook_nightmare', {
                {'gears', 1.00}, {'nightmarefuel', 0.60},
                {'thulecite_pieces', 0.50}, {'copper_ingot', 0.75},
                {'copper_ingot', 0.75}, {'iron_ingot', 1.00},
            }, "rook")
        end
        if MAMConfig.on("mam_drop_bishop") then
            set_rewrite_table('bishop', {
                {'gears', 1.00}, {'gears', 1.00},
                {'bluegem_shard', 1.00}, {'redgem_shard', 1.00},
                {'bluegem_shard', 0.50}, {'redgem_shard', 0.50},
                {'copper_ingot', 0.75}, {'iron_ingot', 1.00},
            }, "bishop")
            set_rewrite_table('bishop_nightmare', {
                {'gears', 1.00}, {'nightmarefuel', 0.60},
                {'thulecite_pieces', 0.50}, {'copper_ingot', 0.50},
                {'iron_ingot', 1.00}, {'purplegem_shard', 1.00},
                {'purplegem_shard', 0.75}, {'purplegem_shard', 0.50},
                {'purplegem_shard', 0.25},
            }, "bishop")
        end
    end

    -- Hounds: Auto cede ao UM; Always soma nossos fragmentos ao loot do UM.
    -- Sem UM, Rewrite restaura as tabelas originais, apos os outros modmain.
    AddSimPostInit(function()
        local hounds_mode = MAMConfig.int("mam_drop_hounds", 1)
        if hounds_mode <= 0 or MAMLootGuard.HasUncompromising() then
            return
        end

        local function apply_hound_rewrite()
            if MAMConfig.on("mam_drop_firehound") then
                set_rewrite_table('hound_fire', {
                    {'monstermeat', 1.00}, {'houndstooth', 1.00},
                    {'houndfire', 1.00}, {'houndfire', 1.00}, {'houndfire', 1.00},
                    {'redgem_shard', 1.00}, {'redgem_shard', 0.75},
                    {'redgem_shard', 0.50}, {'redgem_shard', 0.25},
                }, "firehound")
            end
            if MAMConfig.on("mam_drop_icehound") then
                set_rewrite_table('hound_cold', {
                    {'monstermeat', 1.00}, {'houndstooth', 1.00},
                    {'houndstooth', 1.00}, {'bluegem_shard', 1.00},
                    {'bluegem_shard', 0.75}, {'bluegem_shard', 0.50},
                    {'bluegem_shard', 0.25},
                }, "icehound")
            end
        end
        if TheWorld ~= nil and TheWorld.DoTaskInTime ~= nil then
            TheWorld:DoTaskInTime(0, apply_hound_rewrite)
        else
            apply_hound_rewrite()
        end
    end)
end

local function OnWork(inst, worker, workleft)
    if workleft <= 0 then
        local pt = inst:GetPosition()
		
        SpawnPrefab("rock_break_fx").Transform:SetPosition(pt:Get())
        inst.components.lootdropper:DropLoot(pt)

        if inst.showCloudFXwhenRemoved then
            local fx = SpawnPrefab("collapse_small")
			
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        end

		if not inst.doNotRemoveOnWorkDone then
	        inst:Remove()
		end
    else
        inst.AnimState:PlayAnimation(
            (workleft < TUNING.ROCKS_MINE / 3 and "low") or
            (workleft < TUNING.ROCKS_MINE * 2 / 3 and "med") or
            "full"
        )
		
		local pt = inst:GetPosition()
		
		if math.random() <= 0.15 then
			for k = 1, math.random(3) do
				inst.components.lootdropper:SpawnLootPrefab(inst.dust, pt)
			end
		end
		
		if inst.front then
			inst.front.AnimState:PlayAnimation(
            (workleft < TUNING.ROCKS_MINE / 3 and "low") or
            (workleft < TUNING.ROCKS_MINE * 2 / 3 and "med") or
            "full"
			)
		end
		
    end
end

local function baserock_fn(bank, build, anim, icon, tag, den, child)
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    MakeObstaclePhysics(inst, 1)

    if icon then
        inst.MiniMapEntity:SetIcon(icon)
    end

    inst.AnimState:SetBank(bank)
    inst.AnimState:SetBuild(build)

    if type(anim) == "table" then
        for i, v in ipairs(anim) do
            if i == 1 then
                inst.AnimState:PlayAnimation(v)
            else
                inst.AnimState:PushAnimation(v, false)
            end
        end
    else
        inst.AnimState:PlayAnimation(anim)
    end

    MakeSnowCoveredPristine(inst)

    inst:AddTag("boulder")
    if tag ~= nil then
        inst:AddTag(tag)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("lootdropper") 

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.MINE)
    inst.components.workable:SetWorkLeft(TUNING.ROCKS_MINE)
    inst.components.workable:SetOnWorkCallback(OnWork)

    local color = 0.5 + math.random() * 0.5
	
    inst.AnimState:SetMultColour(color, color, color, 1)

    inst:AddComponent("inspectable")
    
    MakeSnowCovered(inst)
	
	MakeHauntableWork(inst)
	inst.components.inspectable.nameoverride = "ROCK"

    return inst
end

local function rock1_fn()
    local inst = baserock_fn("rock", "ruins_artichoke", "full", "spikyrock.tex")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.lootdropper:SetChanceLootTable('spikyrock')
	
	inst.dust = "copper_dust"	
	
    return inst
end

local function rock2_fn()
    local inst = baserock_fn("rock_basalt", "rock_basalt", "full", "ironrock.tex")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.lootdropper:SetChanceLootTable('ironrock')
	
	inst.dust = "iron_dust"

    return inst
end

return Prefab("spikyrock", rock1_fn, rock1_assets, prefabs),
	Prefab("ironrock", rock2_fn, rock3_assets, prefabs)