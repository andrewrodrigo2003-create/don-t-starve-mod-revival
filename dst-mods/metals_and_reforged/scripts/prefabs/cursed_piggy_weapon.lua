local assets = {
	Asset("ANIM", "anim/cursed_piggy_weapon.zip"),
	Asset("ANIM", "anim/swap_cursed_piggy_weapon.zip"),
	Asset("ATLAS", "images/inventoryimages/cursed_piggy_weapon.xml"),
}
local prefabs = {
	"weaponsparks_fx",
}
local tuning = TUNING.TOT.CURSED_PIGGY_WEAPON

local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_cursed_piggy_weapon", "swap_object")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function OnUnEquip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function OnAttack(inst, attacker, target)
	if attacker and target then
		if math.random(1, 20) == 1 then
			attacker:DoTaskInTime(1.5, function()
				fns.SpawnPrefabsAroundTarget(inst, "cursed_phantom_friendly", 1.5, 2, tuning.PHANTOMS_AMOUNT, 15, 12)
			end)
		end
		SpawnPrefab("weaponsparks_fx"):SetTarget(attacker, target)
	end
end

local function OnFinished(inst)
    inst:Remove()
end

local function RemoveSpeedDebuff(inst)
	inst.components.locomotor.externalspeedmultiplier = 1
	inst:RemoveTag("slowed")
end


local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("cursed_piggy_weapon")
    inst.AnimState:SetBuild("cursed_piggy_weapon")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("weapon")
	inst:AddTag("killerspike")
	inst:AddTag("hide_percentage")

    MakeInventoryPhysics(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(tuning.DAMAGE)
	inst.components.weapon:SetRange(tuning.RANGE)
	--inst.components.weapon:SetOnAttack(OnAttack)

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(100)
    inst.components.finiteuses:SetUses(100)		--(math.random(150,300))
    inst.components.finiteuses:SetOnFinished(OnFinished)

    inst:AddComponent("inspectable")
	
    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "cursed_piggy_weapon"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cursed_piggy_weapon.xml"

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnEquip)
	
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("cursed_piggy_weapon", fn, assets)