require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/quagmire_safe.zip"),
    Asset("ANIM", "anim/ui_largechest_5x5.zip"),
}

local prefabs =
{
    "collapse_small",
}

local function onopen(inst)
    inst.AnimState:PlayAnimation("opened")
    inst.SoundEmitter:PlaySound("dontstarve/common/icebox_open")
end

local function onclose(inst)
    inst.AnimState:PlayAnimation("closed")
    inst.SoundEmitter:PlaySound("dontstarve/common/icebox_close")
end

local function onhammered(inst, worker)
    inst.components.lootdropper:DropLoot()

    -- Nunca deixar materiais presos no container durante a destruicao.
    if inst.components.container ~= nil then
        inst.components.container:DropEverything()
    end

    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onhit(inst, worker)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", false)
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function onbuilt(inst)
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed", false)
    inst.SoundEmitter:PlaySound("dontstarve/common/icebox_craft")
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("icebox_victorian.tex")

    inst:AddTag("structure")
    inst:AddTag("mam_metal_storage")

    inst.AnimState:SetBank("quagmire_safe")
    inst.AnimState:SetBuild("quagmire_safe")
    inst.AnimState:PlayAnimation("closed")

    MakeSnowCoveredPristine(inst)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("lootdropper")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("metal_storage_chest")
    inst.components.container.onopenfn = onopen
    inst.components.container.onclosefn = onclose

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(onhammered)
    inst.components.workable:SetOnWorkCallback(onhit)

    inst:ListenForEvent("onbuilt", onbuilt)
    MakeSnowCovered(inst)
    AddHauntableDropItemOrWork(inst)

    return inst
end

return Prefab("metal_storage_chest", fn, assets, prefabs),
    MakePlacer("metal_storage_chest_placer", "quagmire_safe", "quagmire_safe", "closed")
