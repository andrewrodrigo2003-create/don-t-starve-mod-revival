local assets =
{
	Asset("ANIM", "anim/metal_dusts.zip"),
}

local function MakeRawMetals(name)

	table.insert(assets, Asset("IMAGE", "images/inventoryimages/"..name..".tex"))
	table.insert(assets, Asset("ATLAS", "images/inventoryimages/"..name..".xml"))

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

		inst.AnimState:SetBank("metal_dusts")
		inst.AnimState:SetBuild("metal_dusts")
		inst.AnimState:PlayAnimation(name == "gold_dust" and "idle" or name, true)

		inst:AddTag("raw_metal")
		inst:AddTag("molebait")
		
		if name == "gold_dust" then
			inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		end
		
        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

		inst:AddComponent("inspectable")

		inst:AddComponent("inventoryitem")
		inst.components.inventoryitem.atlasname = "images/inventoryimages/"..name..".xml"

		inst:AddComponent("stackable")
		inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
		
		inst:AddComponent("edible")
		inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
		inst.components.edible.hungervalue = 1

		inst:AddComponent("tradable")
		inst.components.tradable.rocktribute = 1

		MakeHauntableLaunch(inst)
		
		if name == "gold_dust" then
			inst:DoPeriodicTask(4, function() inst.AnimState:PlayAnimation("sparkle") inst.AnimState:PushAnimation("idle") end)
		end

        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local metals = {"copper_dust", "iron_dust", "gold_dust"}

local prefabs = {}

for i, v in pairs(metals) do
    table.insert(prefabs, MakeRawMetals(v))
end

return unpack(prefabs)
