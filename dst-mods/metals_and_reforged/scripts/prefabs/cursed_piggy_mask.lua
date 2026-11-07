local assets = {
    Asset("ANIM", "anim/cursed_piggy_mask.zip"),
	Asset("ATLAS", "images/inventoryimages/cursed_piggy_mask.xml"),
}
local tuning = TUNING.TOT.CURSED_PIGGY_MASK

local function OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_hat", "cursed_piggy_mask", "swap_cursed_piggy_mask")

	owner.AnimState:Show("HAT")
	owner.AnimState:Show("HAIR_HAT")
	if inst.components.fueled ~= nil then
		inst.components.fueled:StartConsuming()
	end
end

local function OnUnEquip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_hat")
	
	owner.AnimState:Hide("HAT")
	owner.AnimState:Hide("HAIR_HAT")
	if inst.components.fueled ~= nil then
		inst.components.fueled:StopConsuming()
	end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("cursed_piggy_mask")
	inst.AnimState:SetBuild("cursed_piggy_mask")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("hat")
	inst:AddTag("nightvision")
	inst:AddTag("hide_percentage")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "cursed_piggy_mask"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cursed_piggy_mask.xml"
	
	inst:AddComponent("inspectable")

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
	inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnEquip)
	
    inst:AddComponent("fueled")
    --inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled:InitializeFuelLevel(TUNING.TOPHAT_PERISHTIME)    --8
    inst.components.fueled:SetDepletedFn(inst.Remove)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("cursed_piggy_mask", fn, assets)