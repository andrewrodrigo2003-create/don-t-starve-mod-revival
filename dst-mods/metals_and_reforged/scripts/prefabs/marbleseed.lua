require "prefabutil"

local assets =
{
    Asset("ANIM", "anim/marbleseed.zip"),
}

local prefabs = {"marbletree"}

local function growtree(inst)
    inst.growtask = nil
    inst.growtime = nil
    inst.issapling:set(false)
    local treenum = math.random(1,4)
	local tree = SpawnPrefab("marbletree_"..treenum)
    if tree then 
		tree.Transform:SetPosition(inst.Transform:GetWorldPosition() ) 
        tree:growfromseed()
        inst:Remove()
	end
end

local function plant(inst, growtime)
    inst:RemoveComponent("inventoryitem")
    MakeHauntableIgnite(inst)
    inst.AnimState:PlayAnimation("planted")
    inst.SoundEmitter:PlaySound("dontstarve/wilson/plant_tree")
    inst.growtime = GetTime() + growtime
    inst.issapling:set(true)
    --print ("PLANT", growtime)
    inst.growtask = inst:DoTaskInTime(growtime, growtree)
end

local function ondeploy(inst, pt)

    inst = inst.components.stackable:Get()
    inst.Physics:Teleport(pt:Get())
    local timeToGrow = GetRandomWithVariance(TUNING.TOTAL_DAY_TIME * 3, TUNING.TOTAL_DAY_TIME * 2)
    plant(inst, timeToGrow)
	
end

local function stopgrowing(inst)
    if inst.growtask then
        inst.growtask:Cancel()
        inst.growtask = nil
    end
    inst.growtime = nil
    inst.issapling:set(false)
end

local function describe(inst)
    if inst.growtime then
        return "PLANTED"
    end
end

local function displaynamefn(inst)
    return STRINGS.NAMES[inst.issapling:value() and "MARBLESEED_SAPLING" or "MARBLESEED"]
end

local function OnSave(inst, data)
    if inst.growtime then
        data.growtime = inst.growtime - GetTime()
    end
end

local function OnLoad(inst, data)
    if data and data.growtime then
        plant(inst, data.growtime)
    end
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("marble_seed")
    inst.AnimState:SetBuild("marbleseed")
    inst.AnimState:PlayAnimation("dropped")

    inst.issapling = net_bool(inst.GUID, "issapling")
    inst.issapling:set(false)

    inst.displaynamefn = displaynamefn

    if not TheWorld.ismastersim then
        return inst
    end

    inst.entity:SetPristine()

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.ELEMENTAL

    inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = describe

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/marbleseed.xml"

    MakeHauntableLaunchAndIgnite(inst)

    inst:AddComponent("deployable")
    inst.components.deployable:SetDeployMode(DEPLOYMODE.PLANT)
    inst.components.deployable.ondeploy = ondeploy

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("common/inventory/marbleseed", fn, assets),
	   MakePlacer("common/marbleseed_placer", "marble_seed", "marbleseed", "planted")