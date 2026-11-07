local assets =
{
    Asset("ANIM", "anim/sharkscale.zip"),
    Asset("IMAGE", "images/inventoryimages/sharkscale.tex"),
    Asset("ATLAS", "images/inventoryimages/sharkscale.xml"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    MakeInventoryFloatable(inst, "med", 0.03, 0.65)

    inst.AnimState:SetBank("sharkscale")
    inst.AnimState:SetBuild("sharkscale")
    inst.AnimState:PlayAnimation("idle")

    

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = 20
    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    --inst.components.inventoryitem:SetSinks(true)
    inst.components.inventoryitem.imagename = "sharkscale"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/sharkscale.xml"

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("sharkscale", fn, assets)