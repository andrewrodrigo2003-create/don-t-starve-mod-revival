local assets=
{
	Asset("ANIM", "anim/halberd.zip"),
	Asset("ANIM", "anim/swap_halberd.zip"),

}

local HALBERD_DAMAGE = 51
local HALBERD_USES = 150

function hungerdrain(inst, data)
	local worker = inst.components.inventoryitem.owner
	if inst.components.inventoryitem.owner ~= nil then
		if worker.sg:HasStateTag("working") then
			worker.components.hunger:DoDelta(-2) 
		else
		end
	end
end

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
        inst._trailtask = inst:DoPeriodicTask(6 * FRAMES, sword_do_trail, 1 * FRAMES)
    end
end

local function sword_unequipped(inst)
    if inst._trailtask ~= nil then
        inst._trailtask:Cancel()
        inst._trailtask = nil
    end
end

local function onfinished(inst)
	inst:Remove()
end

local function onattack(inst, owner, target)
    owner.SoundEmitter:PlaySound("halberdsound/halberdsound/halberdsound")
	if (target:HasTag("leif") or target:HasTag("leif_sparse")) then
		inst.components.weapon:SetDamage(HALBERD_DAMAGE*2)
	else
		inst.components.weapon:SetDamage(HALBERD_DAMAGE)
	end
end

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "swap_halberd", "swap_halberd")
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
	inst.isWeared = true
	if "true"=="true" then
        if "cane_ancient_fx"=="cane_ancient_fx" then
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
	--owner:AddTag("woodcutter")
end

local function onunequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	inst.isWeared = false
	if "true"=="true" then
		if "cane_ancient_fx"=="cane_ancient_fx" then
	   	   sword_unequipped(inst)
		else
			if inst._vfx_fx_inst ~= nil then
				inst._vfx_fx_inst:Remove()
				inst._vfx_fx_inst = nil
			end
		end
	end
    --owner:RemoveTag("woodcutter")
end

local function fn(Sim)
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
   	inst.entity:AddNetwork()
	MakeInventoryPhysics(inst)


	anim:SetBank("halberd")
	anim:SetBuild("halberd")
	anim:PlayAnimation("idle")

	inst:AddTag("halberd")

	inst:AddTag("sharp")
	MakeInventoryFloatable(inst)

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end	
	
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(HALBERD_DAMAGE)
	inst.components.weapon:SetOnAttack(onattack)

	-----
	inst:AddComponent("tool")
	inst.components.tool:SetAction(ACTIONS.CHOP, 7)
	-------
	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(HALBERD_USES)
	inst.components.finiteuses:SetUses(HALBERD_USES)
	inst.components.finiteuses:SetConsumption(ACTIONS.CHOP, 1)
	inst.components.finiteuses:SetOnFinished(onfinished)
	inst:ListenForEvent("percentusedchange", hungerdrain)
	-------

	inst:AddComponent("inspectable")


	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip( onequip )
	inst.components.equippable:SetOnUnequip( onunequip)
	inst.components.equippable.dapperness = -0.25
	inst.components.equippable.walkspeedmult = 0.85
	--inst:AddInherentAction(ACTIONS.CHOP)

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.atlasname = "images/inventoryimages/halberd.xml"
	inst.caminho = "images/inventoryimages/halberd.xml"	
	
	return inst
end

return Prefab( "common/inventory/halberd", fn, assets)
