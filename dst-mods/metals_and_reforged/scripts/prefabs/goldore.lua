local assets = {}

local function ReplaceOld(inst)
    local inventoryitem = inst.components.inventoryitem
    local owner = inventoryitem:GetContainer()
    local slot = inventoryitem:GetSlotNum()
    local pos = inst:GetPosition()
    local stacksize = inst.components.stackable:StackSize()

    local gold = SpawnPrefab("goldnugget")
    if gold == nil or gold.components == nil or gold.components.stackable == nil then
        -- Never destroy the legacy item unless its replacement was created.
        return
    end

    gold.components.stackable:SetStackSize(stacksize)
    gold.Transform:SetPosition(pos.x, pos.y, pos.z)

    if owner ~= nil then
        -- Free the legacy item's slot first. Giving the replacement while the
        -- old item still occupies that slot makes GiveItem reject it and drop
        -- the nuggets beside the owner instead of preserving the inventory.
        local removed = owner:RemoveItem(inst, true)
        if removed == nil then
            gold:Remove()
            -- A read-only/locked owner refused removal. Keep the original item.
            return
        end

        -- Do not auto-drop on failure: the replacement is already positioned at
        -- the legacy item's world position, so a rejecting custom container
        -- cannot send it to an arbitrary/default location.
        owner:GiveItem(gold, slot, pos, false)
    end

    inst:Remove()
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    -- This legacy migration prefab is networked even though it exists only
    -- briefly before being replaced by gold nuggets. Mark it pristine on both
    -- server and clients before the master-sim-only component setup.
    inst.entity:SetPristine()

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
