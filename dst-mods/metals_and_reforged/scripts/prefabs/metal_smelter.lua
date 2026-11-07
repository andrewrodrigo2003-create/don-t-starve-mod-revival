local assets =
{
    Asset("ANIM", "anim/smelter.zip"),
	Asset("ANIM", "anim/new_cooker_ui_1x4.zip"),
	
	Asset("IMAGE", "images/inventoryimages/metal_smelter.tex"),
	Asset("ATLAS", "images/inventoryimages/metal_smelter.xml"),
}

local prefabs =
{
    "collapse_small",
}


local function onhammered(inst, worker)
    inst.components.lootdropper:DropLoot()

	if inst.components.smelter.canharvest and inst.components.smelter.product then
        -- Entrega o lote inteiro, nao uma unidade sola.
        local product = inst.components.smelter.product
        local batch = inst.components.smelter.batch or 1
        local loot = SpawnPrefab(product)
        if loot ~= nil then
            if loot.components.stackable ~= nil then
                local maxsize = loot.components.stackable.maxsize or 20
                loot.components.stackable:SetStackSize(math.min(batch, maxsize))
            end
            inst.components.lootdropper:FlingItem(loot)
        end
	end

    -- As sobras da carga precisam sair antes do entity morrer: o container
    -- vanilla destroi o conteudo no Remove, e sem isto o jogador perdia item.
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
	
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    inst:Remove()
end

--[[
local function onhit(inst, worker)
	if inst.components.smelter.issmelting then
		inst.components.smelter:ResetSmelter()
		inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle")
	elseif inst.components.smelter.canharvest and inst.components.smelter.product then
		inst.components.container:DropEverything()
		inst.AnimState:PlayAnimation("hit_full")
		inst.AnimState:PushAnimation("idle_full")
	else
		inst.components.container:DropEverything()
		inst.AnimState:PlayAnimation("hit")
		inst.AnimState:PushAnimation("idle")
	end
end
]]

local function onhit(inst)

	if inst.components.smelter.issmelting then
		inst.components.smelter:ResetSmelter()
		inst.AnimState:PlayAnimation("hit_empty")
		inst.AnimState:PushAnimation("idle_empty")
	elseif inst.components.smelter.canharvest and inst.components.smelter.product then
		inst.components.container:DropEverything()
		inst.AnimState:PlayAnimation("hit_full")
		inst.AnimState:PushAnimation("idle_full")
	else
		inst.components.container:DropEverything()
		inst.AnimState:PlayAnimation("hit_empty")
		inst.AnimState:PushAnimation("idle_empty")
	end
end

local function onfar(inst)
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle_empty")
    inst.SoundEmitter:PlaySound("dontstarve/common/cook_pot_craft")

    -- Maquina nova em mundo ja carregado: publica cfg+plano para os clientes.
    if inst.components.smelter ~= nil then
        inst.components.smelter:OnBuilt()
    end
end

local function smeltdone(inst)
	local product = inst.components.smelter.product

	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("smelting_pst")
		inst.AnimState:PushAnimation("idle_full")
		inst.SoundEmitter:KillSound("snd")
		inst.Light:Enable(false)

		inst:DoTaskInTime(1/30, function()
			if inst.AnimState:IsCurrentAnimation("smelting_pst") then
                   inst.SoundEmitter:PlaySound("dontstarve/common/dragonfly_chest_craft")
               end
           end )
		inst:DoTaskInTime(8/30, function()
                if inst.AnimState:IsCurrentAnimation("smelting_pst") then
--                   inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/smelter/move_2")
               end
           end )
		inst:DoTaskInTime(14/30, function()
                if inst.AnimState:IsCurrentAnimation("smelting_pst") then
--                   inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/smelter/pour")
               end
           end )
		inst:DoTaskInTime(31/30, function()
                if inst.AnimState:IsCurrentAnimation("smelting_pst") then
--                   inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/smelter/steam")
               end
           end )
        inst:DoTaskInTime(36/30, function()
                if inst.AnimState:IsCurrentAnimation("smelting_pst") then
 --                  inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/smelter/brick")
               end
           end )   
        inst:DoTaskInTime(49/30, function()
                if inst.AnimState:IsCurrentAnimation("smelting_pst") then
 --                  inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/crafted/smelter/move_2")
               end
           end )
	end

	if product == "junk_dust" then
		inst.AnimState:OverrideSymbol("swap_item", "junk_dust", "junk")
	elseif product == "yellowgem" or product == "orangegem" or product == "greengem" or product == "bluegem" or product == "redgem" or product == "purplegem" or product == "opalgem" then
		inst.AnimState:OverrideSymbol("swap_item", "gems", product)
	elseif product == "copper_ore" or product == "iron_ore" or product == "goldnugget" then
		inst.AnimState:OverrideSymbol("swap_item", "metal_ores", product == "copper_ore" and "ore01" or product == "iron_ore" and "ore02" or "nugget01")
	else
		inst.AnimState:OverrideSymbol("swap_item", product, "alloy01")
	end

	inst.Light:Enable(false)
end

local function smeltstart(inst)
	if not inst:HasTag("burnt") then
		inst.AnimState:PlayAnimation("smelting_pre")
--		inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/objects/smelter/move_1")
		inst.AnimState:PushAnimation("smelting_loop", true)
		--play a looping sound
		inst.SoundEmitter:KillSound("snd")
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot", "snd")
		inst.Light:Enable(true)
	end
end


local function onopen(inst)
	if not inst:HasTag("burnt") then
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_open")
	end
end

local function onclose(inst)
	if not inst:HasTag("burnt") then
		-- Bug original: referenciava inst.components.melter, que nao existe
		-- neste entity (o componente e "smelter"), e por isso esta callback
		-- nunca era usado: dava nil-index ao fechar a interface.
		local smelter = inst.components.smelter
		if smelter ~= nil and smelter.issmelting then
			-- segue fundindo: nao interrompe a animacao
		elseif smelter ~= nil and smelter.canharvest then
			inst.AnimState:PlayAnimation("idle_full")
		else
			inst.AnimState:PlayAnimation("idle_empty")
			inst.SoundEmitter:KillSound("snd")
		end
		inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
	end
end

local function harvest(inst)
	inst.AnimState:PlayAnimation("idle_empty")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddSoundEmitter()
	inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.Light:Enable(false)
    inst.Light:SetRadius(.9)
    inst.Light:SetFalloff(0.95)
    inst.Light:SetIntensity(.65)
    inst.Light:SetColour(235/255,62/255,12/255)

    MakeObstaclePhysics(inst, 1)
	
	inst.MiniMapEntity:SetIcon("metal_smelter.tex")

    inst.AnimState:SetBank("smelter")
    inst.AnimState:SetBuild("smelter")
    inst.AnimState:PlayAnimation("idle_empty")

    inst:AddTag("structure")

    MakeSnowCoveredPristine(inst)

    -- Plano autoritativo do servidor, replicado para a UI do cliente:
    -- "produto|quantidade|fase". Declarado antes de SetPristine, como exige
    -- o sistema de rede do DST.
    inst.mam_plan = net_string(inst.GUID, "mam.smelter.plan", "mamplandirty")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
		inst:DoTaskInTime(0, function()
			inst.replica.container:WidgetSetup("smelter")
        end)
        return inst
    end
	
	inst:AddComponent("container")
    inst.components.container:WidgetSetup("smelter")
	inst.components.container.onopenfn = onopen
	inst.components.container.onclosefn = onclose
	
    inst:AddComponent("inspectable")
	
	inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(3,5)
    inst.components.playerprox:SetOnPlayerFar(onfar)

    inst:AddComponent("lootdropper")
	
	inst:AddComponent("smelter")
	inst.components.smelter.startsmeltingfn = smeltstart
	inst.components.smelter.donesmeltingfn = smeltdone
	inst.components.smelter.onharvest = harvest
	
	inst:AddComponent("harvestable")
	
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

	inst:AddComponent("hauntable")
	inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

	inst:ListenForEvent("onbuilt", onbuilt)

    return inst
end

return Prefab("metal_smelter", fn, assets, prefabs),
	MakePlacer("metal_smelter_placer", "smelter", "smelter", "idle_empty")
