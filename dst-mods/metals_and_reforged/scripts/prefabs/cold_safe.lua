require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/quagmire_safe.zip"),
    Asset("ANIM", "anim/ui_largechest_5x5.zip"),
}

local function doanim(inst, worker)
    inst:DoTaskInTime(1 * FRAMES, function(inst)
        inst.Transform:SetScale(1.05, .95, 1.05)
    end)
    inst:DoTaskInTime(2 * FRAMES, function(inst)
        inst.Transform:SetScale(1.1, .90, 1.1)
    end)
    inst:DoTaskInTime(3 * FRAMES, function(inst)
        inst.Transform:SetScale(1.15, .85, 1.15)
    end)
    inst:DoTaskInTime(4 * FRAMES, function(inst)
        inst.Transform:SetScale(1.20, .80, 1.20)
    end)
    inst:DoTaskInTime(5 * FRAMES, function(inst)
        inst.Transform:SetScale(1.15, .85, 1.15)
    end)
    inst:DoTaskInTime(6 * FRAMES, function(inst)
        inst.Transform:SetScale(1.1, .90, 1.1)
    end)
    inst:DoTaskInTime(7 * FRAMES, function(inst)
        inst.Transform:SetScale(1.05, .95, 1.05)
    end)
    inst:DoTaskInTime(8 * FRAMES, function(inst)
        inst.Transform:SetScale(1, 1, 1)
    end)
end

local function onopen(inst)
    doanim(inst)
    inst.AnimState:PlayAnimation("opened")
    inst.SoundEmitter:PlaySound("dontstarve/common/icebox_open")
end

local function onclose(inst)
    doanim(inst)
    inst.AnimState:PlayAnimation("closed")
    inst.SoundEmitter:PlaySound("dontstarve/common/icebox_close") 
end

local function onhammered(inst, worker)
    inst.components.lootdropper:DropLoot()
    inst.components.container:DropEverything()
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("metal")
    inst:Remove()
end

local function onhit(inst, worker)
    inst.AnimState:PlayAnimation("hit")
    inst.components.container:DropEverything()
    inst.AnimState:PushAnimation("closed", false)
    inst.components.container:Close()
end

local function onbuilt(inst)
    doanim(inst)
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
    
    inst:AddTag("fridge")
    inst:AddTag("structure")
    
    inst.AnimState:SetBank("quagmire_safe")
    inst.AnimState:SetBuild("quagmire_safe")
    inst.AnimState:PlayAnimation("closed")

    inst.SoundEmitter:PlaySound("dontstarve/common/ice_box_LP", "idlesound")

    MakeSnowCoveredPristine(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end
    
    inst:AddComponent("inspectable")

    inst:AddComponent("lootdropper")

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("cold_safe")
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

return Prefab("cold_safe", fn, assets),
        MakePlacer("cold_safe_placer", "quagmire_safe", "quagmire_safe", "closed", nil, nil, nil, nil)