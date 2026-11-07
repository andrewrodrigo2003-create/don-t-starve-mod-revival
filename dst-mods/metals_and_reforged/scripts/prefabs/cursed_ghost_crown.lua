local assets = {
    Asset("ANIM", "anim/cursed_ghost_crown.zip"),
	Asset("ATLAS", "images/inventoryimages/cursed_ghost_crown.xml"),
}
local tuning = TUNING.TOT.CURSED_GHOST_CROWN

local function Activate(inst, owner)
	owner:AddTag("ghostlyhided")
	if owner.components.colourtweener then
		owner.components.colourtweener:StartTween({0.2, 0.2, 0.2, 0.2}, 1)
		owner.AnimState:UsePointFiltering(true)
	end
	owner.DynamicShadow:Enable(false)
	owner.MiniMapEntity:SetEnabled(false)
	owner.SoundEmitter:SetMute(true)
	owner.components.locomotor:SetTriggersCreep(false)
	if owner.components.talker then
		owner.components.talker:IgnoreAll("bernie")
	end
	owner._driptrailtask = owner:DoPeriodicTask(0.5, function()
		local fx = SpawnAt("gestalt_trail", owner)
		fx.AnimState:SetAddColour(1,1,1,1)
		fx:FacePoint(owner:GetPosition():Get())
	end)
end

local function Deactivate(inst, owner)
	owner:RemoveTag("ghostlyhided")
	if owner.components.colourtweener then
		owner.components.colourtweener:StartTween({1, 1, 1, 1}, 1)
		owner.AnimState:UsePointFiltering(false)
	end
	owner.DynamicShadow:Enable(true)
	owner.MiniMapEntity:SetEnabled(true)
	owner.SoundEmitter:SetMute(false)
	owner.components.locomotor:SetTriggersCreep(true)
	if owner.components.talker then
		owner.components.talker:StopIgnoringAll("bernie")
	end
	if owner._driptrailtask then
		owner._driptrailtask:Cancel()
		owner._driptrailtask = nil
	end
end

local function OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_hat", "cursed_ghost_crown", "swap_hat")

	owner.AnimState:Show("HAT")
	owner.AnimState:Hide("HAIR_HAT")
	owner.AnimState:Show("HAIR_NOHAT")
	owner.AnimState:Show("HAIR")

	owner.AnimState:Show("HEAD")
	owner.AnimState:Hide("HEAD_HAT")
	
	inst:Activate(owner)

	if inst.components.fueled ~= nil then
		inst.components.fueled:StartConsuming()
	end
	owner:RemoveTag("scarytoprey")
end

local function OnUnEquip(inst, owner)
	owner.AnimState:ClearOverrideSymbol("swap_hat")
	
	owner.AnimState:Hide("HAT")
	owner.AnimState:Hide("HAIR_HAT")
	owner.AnimState:Show("HAIR_NOHAT")
	owner.AnimState:Show("HAIR")

	if owner:HasTag("player") then
		owner.AnimState:Show("HEAD")
		owner.AnimState:Hide("HEAD_HAT")
	end
	
	inst:Deactivate(owner)

	if inst.components.fueled ~= nil then
		inst.components.fueled:StopConsuming()
	end
	owner:AddTag("scarytoprey")
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("cursed_ghost_crown")
	inst.AnimState:SetBuild("cursed_ghost_crown")
	inst.AnimState:PlayAnimation("idle")

	inst:AddTag("hat")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "cursed_ghost_crown"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/cursed_ghost_crown.xml"
	
	inst:AddComponent("inspectable")

	inst:AddComponent("equippable")
	inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
	inst.components.equippable.dapperness = TUNING.DAPPERNESS_MED
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnEquip)
	
	inst:AddComponent("fueled")
	inst.components.fueled.fueltype = FUELTYPE.USAGE
	inst.components.fueled:InitializeFuelLevel(tuning.PERISH_TIME)
	inst.components.fueled:SetDepletedFn(inst.Remove)
	
	inst.Activate = Activate
	inst.Deactivate = Deactivate
	
	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("cursed_ghost_crown", fn, assets)