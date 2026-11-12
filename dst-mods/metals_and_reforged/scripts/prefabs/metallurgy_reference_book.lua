local assets =
{
    Asset("ANIM", "anim/book_maxwell.zip"),
    Asset("SOUND", "sound/together.fsb"),
}

local function OnReadBook(inst, reader)
    if reader ~= nil and reader.ShowPopUp ~= nil then
        reader:ShowPopUp(POPUPS.MAM_METALLURGY_BOOK, true)
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("book_maxwell")
    inst.AnimState:SetBuild("book_maxwell")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("simplebook")
    inst:AddTag("book")

    MakeInventoryFloatable(inst, "med", nil, 0.75)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "waxwelljournal"

    inst:AddComponent("simplebook")
    inst.components.simplebook.onreadfn = OnReadBook

    MakeSmallBurnable(inst, TUNING.MED_BURNTIME)
    MakeSmallPropagator(inst)
    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("metallurgy_reference_book", fn, assets)
