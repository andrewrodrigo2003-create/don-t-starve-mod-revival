local assets=
{
    Asset("ANIM", "anim/willowdoll.zip"),
    Asset("ANIM", "anim/swap_willowdoll.zip"),
  
    Asset("ATLAS", "images/inventoryimages/willowdoll.xml"),
    Asset("IMAGE", "images/inventoryimages/willowdoll.tex"),
}
local function OnEquip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_willowdoll", "swap_willowdoll")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    owner:AddTag("bernieowner")
end
  
local function OnUnequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    owner:RemoveTag("bernieowner")
end
 
local function fn()
  
    local inst = CreateEntity()
 
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddLight()
     
    MakeInventoryPhysics(inst)   
      
    inst.AnimState:SetBank("willowdoll")
    inst.AnimState:SetBuild("willowdoll")
    inst.AnimState:PlayAnimation("idle")
	
   inst.MiniMapEntity:SetIcon("willowdoll.tex")
 
    inst:AddTag("sharp")

    inst:AddTag("light")
    inst.Light:SetRadius(3)
    inst.Light:SetFalloff(.6)
    inst.Light:SetIntensity(0.9)
    inst.Light:SetColour(220/255,209/255,50/255)
    inst.AnimState:SetBloomEffectHandle( "shaders/anim.ksh" )	

    if not TheWorld.ismastersim then
        return inst
    end
 
    inst.entity:SetPristine()
     
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(14)
  
    inst:AddComponent("inspectable")
      
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "willowdoll"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/willowdoll.xml"
      
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip( OnEquip )
    inst.components.equippable:SetOnUnequip( OnUnequip )
	     
    return inst
end
return  Prefab("common/inventory/dst_willowdoll", fn, assets) 