local assets = {}

local function ReplaceOld(inst)
    if inst.components.inventoryitem:GetContainer() then
        local container = inst.components.inventoryitem:GetContainer()
		local gold = SpawnPrefab("goldnugget")
		local slot = inst.components.inventoryitem:GetSlotNum()
		local sz = inst.components.stackable:StackSize()
		
		gold.components.stackable:SetStackSize(sz)		
        container:GiveItem(gold, slot)		
	else
		local gold = SpawnPrefab("goldnugget")
		local pos = inst:GetPosition()
		local sz = inst.components.stackable:StackSize()
		
		gold.components.stackable:SetStackSize(sz)
		gold.Transform:SetPosition(pos.x, pos.y, pos.z)
    end
	
    inst:Remove()
end

local function fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
		
	if not TheWorld.ismastersim then
        return inst
    end
		
    inst:AddComponent("inspectable")
		
    inst:AddComponent("inventoryitem")
		
	inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM
		
	inst:DoTaskInTime(0.1, ReplaceOld)
    
    return inst
end

return Prefab("gold_ore", fn, assets)