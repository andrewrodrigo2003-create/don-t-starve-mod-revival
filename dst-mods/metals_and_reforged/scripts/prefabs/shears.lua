local assets=
{ 
    Asset("ANIM", "anim/shears.zip"),
    Asset("ANIM", "anim/swap_shears.zip"),
    Asset("ATLAS", "images/inventoryimages/shears.xml"),
    Asset("IMAGE", "images/inventoryimages/shears.tex"),
}

local function OnFinished(inst)
	if inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner ~= nil then
		inst.components.inventoryitem.owner:PushEvent("toolbroke", {tool = inst})
	end
	inst:Remove()
end

local function onequip(inst, owner) 
    owner.AnimState:OverrideSymbol("swap_object", "swap_shears", "swap_shears")
    owner.AnimState:Show("ARM_carry") 
    owner.AnimState:Hide("ARM_normal")
end


local function onunequip(inst, owner) 
    owner.AnimState:Hide("ARM_carry") 
    owner.AnimState:Show("ARM_normal")
end


local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    
    inst.AnimState:SetBank("shears")
    inst.AnimState:SetBuild("shears")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("weapon")
    inst:AddTag("bramble_resistant")
    inst:AddTag("shears")
    inst:AddTag("areapicker")
    inst:AddTag("tool")

    inst.entity:SetPristine() 

    MakeInventoryFloatable(inst)

    if not TheWorld.ismastersim then   
      return inst  
    end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(17)

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "shears"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/shears.xml"

	inst:AddComponent("finiteuses")
	inst.components.finiteuses:SetMaxUses(500)
	inst.components.finiteuses:SetUses(500)
	inst.components.finiteuses:SetOnFinished(OnFinished)
    	inst.components.finiteuses:SetConsumption(ACTIONS.AREAPICK, 1)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

	inst:AddComponent("areapicker")
	inst.components.areapicker:SetRadius(4)

    MakeHauntableLaunch(inst) 

    return inst
end


return  Prefab("shears", fn, assets)
