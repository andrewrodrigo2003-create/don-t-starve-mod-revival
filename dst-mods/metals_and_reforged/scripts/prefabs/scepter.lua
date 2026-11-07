local Assets =
{
    Asset("ANIM", "anim/pig_scepter.zip"),
    Asset("ANIM", "anim/swap_pig_scepter.zip"),

    Asset("ATLAS", "images/inventoryimages/pig_scepter_images.xml"),
    Asset("IMAGE", "images/inventoryimages/pig_scepter_images.tex"),
}

local prefabs =
{
    "wormwood_plant_fx",
}

local PLANTS_RANGE = 2
local MAX_PLANTS = 18
local PLANTFX_TAGS = { "wormwood_plant_fx" }

local function DoPlantBloom(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    if #TheSim:FindEntities(x, y, z, PLANTS_RANGE, PLANTFX_TAGS) < MAX_PLANTS then
        local map = TheWorld.Map
        local pt = Vector3(0, 0, 0)
        local offset = FindValidPositionByFan(
            math.random() * 2 * PI,
            math.random() * PLANTS_RANGE,
            3,
            function(offset)
                pt.x = x + offset.x
                pt.z = z + offset.z
                return map:CanPlantAtPoint(pt.x, 0, pt.z)
                    and #TheSim:FindEntities(pt.x, 0, pt.z, .5, PLANTFX_TAGS) < 3
                    and map:IsDeployPointClear(pt, nil, .5)
                    and not map:IsPointNearHole(pt, .4)
            end
        )
    if offset ~= nil then
            local plant = SpawnPrefab("wormwood_plant_fx")
            plant.Transform:SetPosition(x + offset.x, 0, z + offset.z)
            --randomize, favoring ones that haven't been used recently
            local rnd = math.random()
            rnd = table.remove(inst.plantpool, math.clamp(math.ceil(rnd * rnd * #inst.plantpool), 1, #inst.plantpool))
            table.insert(inst.plantpool, rnd)
            plant:SetVariation(rnd)
    end
    end
end

local function OnStartBlooming(inst)
    --inst._bloomtask = inst:DoPeriodicTask(3 * FRAMES, DoPlantBloom2, 2 * FRAMES)
    inst._bloomtask = inst:DoPeriodicTask(.15, DoPlantBloom)
end

local function StartBlooming(inst)
    if inst._bloomtask == nil then
        inst._bloomtask = inst:DoTaskInTime(0, OnStartBlooming)
    end
end

local function StopBlooming(inst)
	if inst._bloomtask ~= nil then
		inst._bloomtask:Cancel()
		inst._bloomtask = nil
	end
	if inst._bloomtaskend ~= nil then
		inst._bloomtaskend:Cancel()
		inst._bloomtaskend = nil
	end
end

---------------------------------------------------------------

local function turnon(inst)
    	if not inst.components.fueled:IsEmpty() then
		inst.Light:Enable(true)
        	inst.components.fueled:StartConsuming()
   	end
end

local function turnoff(inst)
    inst.Light:Enable(false)
    inst.components.fueled:StopConsuming()
end

local function nofuel(inst)
    if inst.components.equippable:IsEquipped() and inst.components.inventoryitem.owner ~= nil then
        turnoff(inst)
    end
end

local function ontakefuel(inst)
    if inst.components.equippable:IsEquipped() or not inst.components.inventoryitem:IsHeld() then
        (inst.components.inventoryitem.owner ~= nil and inst.components.inventoryitem.owner.SoundEmitter or inst.SoundEmitter):PlaySound("dontstarve/common/nightmareAddFuel")
        turnon(inst)
    end
end

local function OnLoad(inst, data)
    if inst.components.fueled:IsEmpty() then
        nofuel(inst)
    end

--[[
	if (inst.components.equippable:IsEquipped() or not inst.components.inventoryitem:IsHeld()) and TheWorld.state.isday then
		--turnoff(inst)
		StartBlooming(inst)
	else
		--if not inst.components.fueled:IsEmpty() then
		--	turnon(inst)
		--end
		StopBlooming(inst)
	end
]]
end

---------------------------------------------------------------
--Sparks trail

local function sword_do_trail(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner() or inst
    if not owner.entity:IsVisible() then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    if owner.sg ~= nil and owner.sg:HasStateTag("moving") then
        local theta = -owner.Transform:GetRotation() * DEGREES
        local speed = owner.components.locomotor:GetRunSpeed() * .1
        x = x + speed * math.cos(theta)
        z = z + speed * math.sin(theta)
    end
    local mounted = owner.components.rider ~= nil and owner.components.rider:IsRiding()
    local map = TheWorld.Map
    local offset = FindValidPositionByFan(
        math.random() * 2 * PI,
        (mounted and 1 or .5) + math.random() * .5,
        4,
        function(offset) 
            local pt = Vector3(x + offset.x, 0, z + offset.z)
            return map:IsPassableAtPoint(pt:Get())
                and not map:IsPointNearHole(pt)
                and #TheSim:FindEntities(pt.x, 0, pt.z, .7, { "shadowtrail" }) <= 0
        end
    )

    if offset ~= nil then 
        SpawnPrefab("cane_ancient_fx").Transform:SetPosition(x + offset.x, 0, z + offset.z)
    end
end

local function sword_equipped(inst)
    if inst._trailtask == nil then
        inst._trailtask = inst:DoPeriodicTask(6 * FRAMES, sword_do_trail, 2 * FRAMES)
    end
end

local function sword_unequipped(inst)
    if inst._trailtask ~= nil then
        inst._trailtask:Cancel()
        inst._trailtask = nil
    end
end

--End of Sparks trail
---------------------------------------------------------------

local function onequip(inst, owner)
        owner.AnimState:OverrideSymbol("swap_object", "swap_pig_scepter", "swap_pig_scepter")
        owner.AnimState:Show("ARM_carry") 
        owner.AnimState:Hide("ARM_normal") 
	inst.isWeared = true
	if "true"=="true" then
	   	if "true"=="false" then
			sword_equipped(inst)
		else
			if inst._vfx_fx_inst == nil then
				inst._vfx_fx_inst = SpawnPrefab("cane_victorian_fx")
				inst._vfx_fx_inst.entity:AddFollower()
			end
			inst._vfx_fx_inst.entity:SetParent(owner.entity)
			inst._vfx_fx_inst.Follower:FollowSymbol(owner.GUID, "swap_object", 0, inst.vfx_fx_offset or 0, 0)
		end
	end
end

local function onunequip(inst, owner) 
	owner.AnimState:Hide("ARM_carry") 
	owner.AnimState:Show("ARM_normal")
	inst.isWeared = false
	if "true"=="true" then
		if "true"=="false" then
			sword_unequipped(inst)
		else
			if inst._vfx_fx_inst ~= nil then
				inst._vfx_fx_inst:Remove()
				inst._vfx_fx_inst = nil
			end
		end
	end
end

local function checkstatus(inst)
if not TheWorld.state.isnight then
	turnoff(inst)
	if inst.components.equippable:IsEquipped() or not inst.components.inventoryitem:IsHeld() then
		StartBlooming(inst)
	end
else
	if inst.components.equippable:IsEquipped() or not inst.components.inventoryitem:IsHeld() then
		turnon(inst)
	end
	StopBlooming(inst)
end

end

local function onputininventory(inst)
	StopBlooming(inst)
	turnoff(inst)
end

local light = TUNING.LIGHT_TOGGLE

local function fn()

    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork() 
    MakeInventoryPhysics(inst)	
    inst.AnimState:SetBank("pig_scepter")
    inst.AnimState:SetBuild("pig_scepter")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("regal")
    inst:AddTag("waterproofer")

    local swap_data1 = {sym_build = "swap_pig_scepter", bank = "pig_scepter"}
    MakeInventoryFloatable(inst, "med", 0.05, {1.8, 0.4, 1.8}, true, -20, swap_data1)

    inst.entity:SetPristine()

local light = inst.entity:AddLight()
    light:Enable(false)
    --light:Enable(true)
    light:SetFalloff(1)
    light:SetIntensity(0.5)
    light:SetRadius(6)
    --light:SetColour(180/255, 195/255, 150/255)
    light:SetColour(228/255, 46/255, 255/255)


    if not TheWorld.ismastersim then   
        return inst  
    end

    inst.plantpool = { 1, 2, 3, 4 }
    for i = #inst.plantpool, 1, -1 do
        table.insert(inst.plantpool, table.remove(inst.plantpool, math.random(i)))
    end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(32)
    inst.components.weapon:SetRange(1.6)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "pig_scepter_images"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/pig_scepter_images.xml"
    inst.components.inventoryitem:SetOnPutInInventoryFn(onputininventory)
    --inst.components.inventoryitem:SetSinks(true)


    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = TUNING.CANE_SPEED_MULT
    --inst.components.equippable.dapperness = 0.05
    
    inst:AddComponent("fueled")
    inst.components.fueled.secondaryfueltype = FUELTYPE.NIGHTMARE
    inst.components.fueled.fueltype = FUELTYPE.OSSIFY
    inst.components.fueled:InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME*0.5)	--0.2
    inst.components.fueled:SetDepletedFn(nofuel)
    inst.components.fueled:SetTakeFuelFn(ontakefuel)
    inst.components.fueled.accepting = true

    inst:DoPeriodicTask(0, function()
	checkstatus(inst)
    end)

    inst.OnLoad = OnLoad

    return inst
end

return Prefab( "common/inventory/scepter", fn, Assets)