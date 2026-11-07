local assets =
{
	Asset("ANIM", "anim/gem_shards.zip"),
}

local function MakeGemShard(name)

	table.insert(assets, Asset("IMAGE", "images/inventoryimages/"..name.."gem_shard.tex"))
	table.insert(assets, Asset("ATLAS", "images/inventoryimages/"..name.."gem_shard.xml"))

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

		inst.AnimState:SetBank("gem_shards")
		inst.AnimState:SetBuild("gem_shards")
		inst.AnimState:PlayAnimation(name.."gem_shard")

		inst:AddTag("gem_shard")
		inst:AddTag("molebait")
		
        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

		inst:AddComponent("inspectable")

		inst:AddComponent("inventoryitem")
		inst.components.inventoryitem.atlasname = "images/inventoryimages/"..name.."gem_shard.xml"

		inst:AddComponent("stackable")
		inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

		inst:AddComponent("edible")
		inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
		inst.components.edible.hungervalue = 1

		inst:AddComponent("tradable")
		inst.components.tradable.rocktribute = 1
	
		
		MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name.."gem_shard", fn, assets, prefabs)
end

local colours = {"red", "yellow", "blue", "purple", "green", "orange"}

local prefabs = {}

for i, v in pairs(colours) do
    table.insert(prefabs, MakeGemShard(v))
end

return unpack(prefabs)
