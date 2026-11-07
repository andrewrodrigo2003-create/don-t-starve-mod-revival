require "prefabutil"

local function shine(inst)
    if not inst.AnimState:IsCurrentAnimation("sparkle") then
        inst.AnimState:PlayAnimation("sparkle")
        inst.AnimState:PushAnimation("idle", false)
    end
    inst:DoTaskInTime(4 + math.random() * 5, shine)
end

local function make_product(data)
    local assets = {}
	
	if data.oldprefab then
		return Prefab(data.name.."_dummy", function() end, assets)
	end

	if data.ore then
		table.insert(assets, Asset("ANIM", "anim/metal_ores.zip"))
	else
		table.insert(assets, Asset("ANIM", "anim/"..data.name..".zip"))
	end

	table.insert(assets, Asset("IMAGE", "images/inventoryimages/"..data.name..".tex")) 
	table.insert(assets, Asset("ATLAS", "images/inventoryimages/"..data.name..".xml"))

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(data.ore and "metal_ores" or data.bank or data.name)
        inst.AnimState:SetBuild(data.ore and "metal_ores" or data.build or data.name)
        inst.AnimState:PlayAnimation(data.ore and data.name or "idle")
		
		if data.name == "gold_ingot" then
			inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
		elseif data.name == "iron_ore" then
			inst.AnimState:OverrideSymbol("ore01", "metal_ores", "ore02")
		end

		inst:AddTag(data.ore and "metal_ore" or "metal_ingot")
		inst:AddTag("molebait")
		
        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end
		
        inst:AddComponent("inspectable")
		
        inst:AddComponent("inventoryitem")
		inst.components.inventoryitem.atlasname = "images/inventoryimages/"..data.name..".xml"

		inst:AddComponent("stackable")
		if data.ore then
			inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM
		elseif data.dust then
			inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM
		else
			inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM
		end
	
		inst:AddComponent("edible")
		inst.components.edible.foodtype = FOODTYPE.ELEMENTAL
		inst.components.edible.hungervalue = 1
		
		inst:AddComponent("bait")

		inst:AddComponent("tradable")
		inst.components.tradable.rocktribute = data.ore and 2 or 4
	
		MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(data.name, fn, assets)
end	

local smelterproducts = require("smelting_products")

local prefabs = {}

for k, v in pairs(smelterproducts) do
    table.insert(prefabs, make_product(v))
end

return unpack(prefabs)
