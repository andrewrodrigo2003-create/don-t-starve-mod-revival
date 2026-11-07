local assets =
{
	Asset("ANIM", "anim/armor_hpdamager.zip"),
}

local function OnBlocked(owner) 
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour") 
end


local function onequip(inst, owner) 
    owner.AnimState:OverrideSymbol("swap_body", "armor_hpdamager", "swap_body")

    inst:ListenForEvent("blocked", OnBlocked, owner)
end

local function onunequip(inst, owner) 
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", OnBlocked, owner)
end

local function fn()
	local inst = CreateEntity()
    
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_hpdamager")
    inst.AnimState:SetBuild("armor_hpdamager")
    inst.AnimState:PlayAnimation("anim")

    inst:AddTag("metal")

    inst.foleysound = "dontstarve/movement/foley/metalarmour"
    
    if not TheWorld.ismastersim then
        return inst
    end

    inst.entity:SetPristine()
    
    inst:AddComponent("inspectable")
    
    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "lavaarena_armor_hpdamager"
    
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(1500, 0.85)
    
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
	inst.components.equippable.walkspeedmult = 1.1
    
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    MakeHauntableLaunch(inst)
    
    return inst
end

return Prefab("common/inventory/jagged_armor", fn, assets)