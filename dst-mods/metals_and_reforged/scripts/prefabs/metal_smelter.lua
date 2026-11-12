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

local MAMContainerSettings = require("mam/container_settings")
local MAMConfig = require("mam/config")

local function onmamplandirty(inst)
    local container = inst.replica ~= nil and inst.replica.container or nil
    if MAMContainerSettings.needs_widget_refresh(inst, container) then
        container:WidgetSetup("smelter")
    end
end


local function restore_hammer_work(inst)
    local workable = inst.components.workable
    if workable ~= nil and workable.SetWorkLeft ~= nil then
        workable:SetWorkLeft(1)
    end
end

local function remove_staged_items(staged, first)
    for index = first or 1, #staged do
        local item = staged[index].item
        if item ~= nil and item.IsValid ~= nil and item:IsValid() then
            item:Remove()
        elseif item ~= nil and item.Remove ~= nil then
            item:Remove()
        end
    end
end

local function onhammered(inst, worker)
    local smelter = inst.components.smelter
    local lootdropper = inst.components.lootdropper

    -- Interromper uma fundicao ativa precisa primeiro concluir o estorno.
    -- Se o estorno falhar, a maquina continua no mundo para nova tentativa.
    if smelter ~= nil and smelter.issmelting then
        local ok, reset = pcall(smelter.ResetSmelter, smelter)
        if not ok or reset == false then
            restore_hammer_work(inst)
            return
        end
    end

    -- Prepare the complete ready output before delivering any stack. A failed
    -- spawn must not destroy the furnace or silently discard the remaining batch.
    local staged = {}
    local remaining = 0
    if smelter ~= nil and smelter.canharvest and smelter.product ~= nil then
        local product = smelter.product
        remaining = math.max(0, math.floor(tonumber(smelter.batch) or 1))
        local to_stage = remaining
        while to_stage > 0 do
            local ok, loot = pcall(SpawnPrefab, product)
            if not ok or loot == nil then
                remove_staged_items(staged)
                restore_hammer_work(inst)
                print("[Metals and More] Falha ao preparar produto da forja; lote preservado para nova tentativa.")
                return
            end

            local amount = 1
            local stackable = loot.components ~= nil and loot.components.stackable or nil
            if stackable ~= nil then
                local maxsize = tonumber(stackable.maxsize) or 20
                amount = maxsize > 0 and math.min(to_stage, maxsize) or 1
                if amount > 1 then
                    local set_ok = pcall(stackable.SetStackSize, stackable, amount)
                    if not set_ok then
                        loot:Remove()
                        remove_staged_items(staged)
                        restore_hammer_work(inst)
                        return
                    end
                end
            end

            table.insert(staged, { item = loot, amount = amount })
            to_stage = to_stage - amount
        end
    end

    -- Commit output one stack at a time. If delivery fails, retain only the
    -- undelivered quantity on the still-existing furnace; never duplicate a
    -- stack already flung into the world.
    for index, entry in ipairs(staged) do
        local ok, result = pcall(lootdropper.FlingItem, lootdropper, entry.item)
        if not ok or result == false then
            remove_staged_items(staged, index)
            if smelter ~= nil then
                smelter.batch = remaining
            end
            restore_hammer_work(inst)
            return
        end
        remaining = remaining - entry.amount
        if smelter ~= nil then
            smelter.batch = remaining
        end
    end

    if lootdropper ~= nil then
        lootdropper:DropLoot()
    end

    -- Container contents leave before entity removal so vanilla cleanup cannot
    -- destroy them silently.
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
    if fx ~= nil then
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        fx:SetMaterial("stone")
    end
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
		local reset = inst.components.smelter:ResetSmelter()
		if reset == false then
			-- Estorno temporariamente indisponivel: preserve o estado visual ativo.
			return
		end
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
        -- O primeiro WidgetSetup pode ocorrer antes de mam_plan chegar do
        -- servidor. Reaplica somente se o netvar publicar outro valor de lote.
        inst:ListenForEvent("mamplandirty", onmamplandirty)
		inst:DoTaskInTime(0, function()
			if inst:IsValid() and inst.replica ~= nil and inst.replica.container ~= nil then
                inst.replica.container:WidgetSetup("smelter")
            end
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

    -- Low-frequency server-side poll; disabled by default. The component
    -- itself validates a fueled collector robot and compatible nearby storage.
    if MAMConfig.on("mam_robot_smelting") then
        inst._mam_robot_smelting_task = inst:DoPeriodicTask(5, function()
            if inst:IsValid() and inst.components.smelter ~= nil then
                inst.components.smelter:TryStartRobotBatch()
            end
        end)
    end
	
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
