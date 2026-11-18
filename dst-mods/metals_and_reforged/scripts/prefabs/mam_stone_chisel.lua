local assets = {
    Asset("ANIM", "anim/pumpkincarver.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("pumpkincarver")
    inst.AnimState:SetBuild("pumpkincarver")
    inst.AnimState:PlayAnimation("carver1")
    inst:AddTag("mam_stone_chisel")
    MakeInventoryFloatable(inst, "small", 0.15, { 1.2, 1, 1.2 })

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("pumpkincarver1")
    inst:AddComponent("inspectable")
    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("mam_stone_chisel", fn, assets)
