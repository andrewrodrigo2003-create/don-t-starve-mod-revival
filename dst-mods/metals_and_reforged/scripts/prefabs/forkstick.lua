local assets =
{
	Asset("ANIM", "anim/forkstick.zip"),
	Asset("ANIM", "anim/swap_forkstick.zip"),

	Asset("ATLAS", "images/inventoryimages/forkstick.xml"),
	Asset("IMAGE", "images/inventoryimages/forkstick.tex"),
}

local prefabs =
{
    "weregoose_splash_med1",
    "weregoose_splash_med2",
    "weregoose_ripple1",
    "weregoose_ripple2",
    "chester_transform_fx",
}

---------------------------------------------------------------------------

local function DoEarthShift(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local efx = SpawnPrefab("groundpoundring_fx")
    efx.Transform:SetPosition(x, y, z)
    --efx.Transform:SetScale(.75, .75, .75)
    efx.Transform:SetScale(2, 2, 2)
end

local function StartEarthshift(inst)
    inst.earthshift = inst:DoTaskInTime(0, DoEarthShift)
end

---------------------------------------------------------------------------

local function onfinished(inst)
    inst:Remove()
end

local function DoRipple(inst)
    if inst.components.drownable ~= nil and inst.components.drownable:IsOverWater() and not inst:HasTag("playerghost") then
        SpawnPrefab("weregoose_ripple"..tostring(math.random(2))).entity:SetParent(inst.entity)
    end
end

local function DoSplash(inst)
    if inst.components.drownable ~= nil and inst.components.drownable:IsOverWater() and inst.sg:HasStateTag("moving") and not inst:HasTag("playerghost") then
        SpawnPrefab("weregoose_splash_med"..tostring(math.random(2))).entity:SetParent(inst.entity)
    end
end

local function DoWetness(inst)
    if inst.components.drownable ~= nil and inst.components.drownable:IsOverWater() then
        --if inst.components.moisture then
        local equipamentos = inst.components.inventory:GetWaterproofness()
        local coberturas = inst.components.moisture.inherentWaterproofness 
        local variante = equipamentos + coberturas
        if variante > 1 then variante = 1 end
        local quantidadefinal = 1 - variante
        inst.components.moisture:DoDelta(0.6*quantidadefinal)    
        --end
    end 
end

local function ShouldNotDrown(inst)
    if inst.components.drownable ~= nil then
        if inst.components.drownable.enabled ~= false then
            inst.components.drownable.enabled = false
            if not inst:HasTag("playerghost") then
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.GROUND)
                inst.Physics:CollidesWith(COLLISION.OBSTACLES)
                inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
                inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                inst.Physics:CollidesWith(COLLISION.GIANTS)
                inst.Physics:Teleport(inst.Transform:GetWorldPosition())
                if inst.goosewettask == nil then
                	inst.goosewettask = inst:DoPeriodicTask(2, DoWetness, FRAMES)
                end
            end
        end
    end
end

local function ShouldDrown(inst)
    if inst.components.drownable ~= nil then
        if inst.components.drownable.enabled == false then
           inst.components.drownable.enabled = true
            if not inst:HasTag("playerghost") then
                inst.Physics:ClearCollisionMask()
                inst.Physics:CollidesWith(COLLISION.WORLD)
                inst.Physics:CollidesWith(COLLISION.OBSTACLES)
                inst.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
                inst.Physics:CollidesWith(COLLISION.CHARACTERS)
                inst.Physics:CollidesWith(COLLISION.GIANTS)
                inst.Physics:Teleport(inst.Transform:GetWorldPosition())
                if TUNING.AGUA == 1 then
	                if inst.goosewettask ~= nil then
	                inst.goosewettask:Cancel()
	                inst.goosewettask = nil
	            	end
                end
            end
        end
    end
end

local function onequip(inst, owner) 
    owner.AnimState:OverrideSymbol("swap_object", "swap_forkstick", "swap_forkstick")
    owner.AnimState:Show("ARM_carry") 
    owner.AnimState:Hide("ARM_normal") 

    owner:ShakeCamera(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)

    inst.SoundEmitter:PlaySound("dontstarve/rain/thunder_close", nil, nil, true)

	if owner.components.moisture then 
		owner.components.moisture:DoDelta(20) 
	end
	if owner.components.inventoryitemmoisture then 
		owner.components.inventoryitemmoisture:DoDelta(20) 
	end

    if not owner:HasTag("playerghost") then
        if owner.gooserippletask == nil then
            owner.gooserippletask = owner:DoPeriodicTask(.7, DoRipple, FRAMES)
        end
        if owner.goosesplashtask == nil then
            owner.goosesplashtask = owner:DoPeriodicTask(.3, DoSplash, FRAMES)
        end
    else
        if owner.gooserippletask ~= nil then
            owner.gooserippletask:Cancel()
            owner.gooserippletask = nil
        end
        if owner.goosesplashtask ~= nil then
            owner.goosesplashtask:Cancel()
            owner.goosesplashtask = nil
        end
    end

    StartEarthshift(inst)

    ShouldNotDrown(owner)   
    inst.components.fueled:StartConsuming()
end

local function onunequip(inst, owner) 
    owner.AnimState:Hide("ARM_carry") 
    owner.AnimState:Show("ARM_normal") 

    owner:ShakeCamera(CAMERASHAKE.SIDE, .5, .05, .1, inst, 40)
    inst.SoundEmitter:PlaySound("dontstarve/rain/thunder_close", nil, nil, true)

    if owner.gooserippletask ~= nil then
            owner.gooserippletask:Cancel()
            owner.gooserippletask = nil
    end
    if owner.goosesplashtask ~= nil then
            owner.goosesplashtask:Cancel()
            owner.goosesplashtask = nil
    end
    
    StartEarthshift(inst)

    ShouldDrown(owner)   
    inst.components.fueled:StopConsuming()
end

local function init()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("forkstick")
    inst.AnimState:SetBuild("forkstick")
    inst.AnimState:PlayAnimation("idle")

    inst.entity:AddNetwork()
		
    if not TheWorld.ismastersim then
	return inst
    end
		
    inst.entity:SetPristine()
		
    MakeHauntableLaunch(inst)

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(math.random(12,99))

    inst:AddComponent("inspectable")
    
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.atlasname = "images/inventoryimages/forkstick.xml"
    inst.components.inventoryitem.imagename = "forkstick"
    
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("fueled")
    --inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled:InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME*0.5)    --8
    inst.components.fueled:SetDepletedFn(inst.Remove)

	inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(50)
    inst.components.finiteuses:SetUses(50)
    inst.components.finiteuses:SetOnFinished( onfinished )

    return inst
end

return Prefab("common/inventory/forkstick", init, assets, prefabs)