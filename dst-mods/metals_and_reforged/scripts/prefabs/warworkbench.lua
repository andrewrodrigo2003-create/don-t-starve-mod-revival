require "prefabutil"

local assets =
{
	Asset("ANIM", "anim/workbench_obsidian.zip"),
	Asset("MINIMAP_IMAGE", "obsidian_workbench"),
}

local function onhammered(inst, worker)
	inst.components.lootdropper:DropLoot()
	SpawnPrefab("collapse_big").Transform:SetPosition(inst.Transform:GetWorldPosition())
	inst.SoundEmitter:PlaySound("dontstarve/common/destroy_stone")
	inst:Remove()
end

local function OnTurnOff(inst)
    inst.components.prototyper.on = false  -- prototyper doesn't set this until after this function is called
    inst.AnimState:PlayAnimation("proximity_pst")
    inst.AnimState:PushAnimation("idle", true)
    inst.SoundEmitter:KillSound("loop")
end

local function OnTurnOn(inst)
    inst.components.prototyper.on = true  -- prototyper doesn't set this until after this function is called!!
    inst.AnimState:PlayAnimation("proximity_pre")
    inst.AnimState:PushAnimation("proximity_loop", true)
end

local function onhit(inst, worker)
	inst.AnimState:PlayAnimation("proximity_loop", true)
	inst.AnimState:PushAnimation("proximity_loop", true)
end

local function onbuilt(inst)
	inst.AnimState:PlayAnimation("proximity_pre")
	inst.AnimState:PushAnimation("proximity_loop", true)
end

local function InitFn(Sim)
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddMiniMapEntity()
	inst.entity:AddNetwork()

	--inst.MiniMapEntity:SetIcon("firepit.png")
    --inst.MiniMapEntity:SetPriority(1)
    inst.Transform:SetScale(1,1,1)
	
	inst.AnimState:SetBank("workbench_obsidian")
	inst.AnimState:SetBuild("workbench_obsidian")
	inst.AnimState:PlayAnimation("idle")
	
	MakeObstaclePhysics(inst, 1, 1.2)	--2,1.2
	
	inst:AddTag("prototyper")

	inst:AddTag("structure")
	
	inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("inspectable")
	
	inst:AddComponent("prototyper")
	inst.components.prototyper.trees = TUNING.PROTOTYPER_TREES.ALCHEMY_ONE
		inst.components.prototyper.onturnon = OnTurnOn
	inst.components.prototyper.onturnoff = OnTurnOff
	inst.components.prototyper.onactivate = function()
        inst.AnimState:PlayAnimation("use")
        inst.AnimState:PushAnimation("proximity_loop", true)
	end

	inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)
	
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
	inst.components.workable:SetOnFinishCallback(onhammered)
	inst.components.workable:SetOnWorkCallback(onhit)
	inst.components.workable:SetWorkLeft(3)

	inst:ListenForEvent("onbuilt", onbuilt)

	return inst
end

return Prefab("warworkbench", InitFn, assets, prefabs),
MakePlacer("warworkbench_placer", "workbench_obsidian", "workbench_obsidian", "idle")  
