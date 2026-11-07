local assets =
{
    Asset("ANIM", "anim/hammer_mjolnir.zip"),
    Asset("ANIM", "anim/swap_hammer_mjolnir.zip")
}

function hungerdrain(inst, data)
	local worker = inst.components.inventoryitem.owner
	if inst.components.inventoryitem.owner ~= nil then
		if worker.sg:HasStateTag("working") then
			worker.components.hunger:DoDelta(-5) 
		else
		end
	end
end

local function DoEarthShift(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local efx = SpawnPrefab("groundpoundring_fx")
    efx.Transform:SetPosition(x, y, z)
    efx.Transform:SetScale(.75, .75, .75)
end

local function StartEarthshift(inst)
    inst.earthshift = inst:DoTaskInTime(0, DoEarthShift)
end

local MINE_TAGS = {"MINE_workable"}
local MINE_NOT_TAGS = {"INLIMBO"}

local function FinishedWork(owner, data)
	local x, y, z = owner.Transform:GetWorldPosition()
	owner:ShakeCamera(CAMERASHAKE.SIDE, 1, 0.02, 0.25)
	owner:DoTaskInTime(0, DoEarthShift)
	owner.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/ice_attack", nil, 0.5)
	local ents = TheSim:FindEntities(x, y, z, 1, MINE_TAGS, MINE_NOT_TAGS)	--3
	for k, v in pairs(ents) do
		if (v.prefab == data.target.prefab) and v.components.workable and
			v.components.workable:CanBeWorked() and
			v.components.workable:GetWorkAction() == ACTIONS.MINE then
			v.components.workable:WorkedBy(owner, 1)
			SpawnPrefab("shovel_dirt").Transform:SetPosition(v.Transform:GetWorldPosition())
		end
	end
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object","swap_hammer_mjolnir","swap_hammer_mjolnir")
    -------
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

	inst:ListenForEvent("working", FinishedWork, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
	
	inst:RemoveEventCallback("working", FinishedWork, owner)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("hammer_mjolnir")
    inst.AnimState:SetBuild("hammer_mjolnir")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("hammer")
    inst:AddTag("tool")
    inst:AddTag("weapon")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    -------
    inst:AddComponent("tool")
    inst.components.tool:SetAction(ACTIONS.HAMMER, 15)	--without
    inst.components.tool:SetAction(ACTIONS.MINE, 15)	--1.75
    -------
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.HAMMER_DAMAGE)
    -------
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "hammer_mjolnir"
    -------
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
--NEW
    inst:AddInherentAction(ACTIONS.HAMMER)
    -------
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.HAMMER_USES*0.5)	--*2
    inst.components.finiteuses:SetUses(TUNING.HAMMER_USES*0.5)	--*2
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.finiteuses:SetConsumption(ACTIONS.HAMMER, 1)
    inst.components.finiteuses:SetConsumption(ACTIONS.MINE, 1.5)
    inst:ListenForEvent("percentusedchange", hungerdrain)
    -------

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("forginghammerold", fn, assets)
