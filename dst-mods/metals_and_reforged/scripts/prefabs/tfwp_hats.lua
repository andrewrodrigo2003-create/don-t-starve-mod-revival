local function OnEqipHelm(inst, owner)
    owner.AnimState:Show("HAT")
    owner.AnimState:Show("HAIR_HAT")
    owner.AnimState:Hide("HAIR_NOHAT")
    owner.AnimState:Hide("HAIR")

    owner.AnimState:OverrideSymbol("swap_hat", "hat_" .. inst._baseBuild, "swap_hat")

    if owner:HasTag("player") then
        owner.AnimState:Hide("HEAD")
        owner.AnimState:Show("HEAD_HAT")
    end

    if inst.components.fueled then
        inst.components.fueled:StartConsuming()
    end
end

local function OnEqipCrown(inst, owner)
    owner.AnimState:Show("HAT")
    owner.AnimState:OverrideSymbol("swap_hat", "hat_" .. inst._baseBuild, "swap_hat")

    if inst.components.fueled then
        inst.components.fueled:StartConsuming()
    end
end

local function OnUneqipHelm(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_hat")
    owner.AnimState:Hide("HAT")
    owner.AnimState:Hide("HAIR_HAT")
    owner.AnimState:Show("HAIR_NOHAT")
    owner.AnimState:Show("HAIR")

    if owner:HasTag("player") then
        owner.AnimState:Show("HEAD")
        owner.AnimState:Hide("HEAD_HAT")
    end

    if inst.components.fueled then
        inst.components.fueled:StopConsuming()
    end
end

local function OnUneqipCrown(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_hat")
    owner.AnimState:Hide("HAT")

    if inst.components.fueled then
        inst.components.fueled:StopConsuming()
    end
end

local function SetModifiers(inst, owner, mods)
    if mods.damage and owner.components.combat ~= nil then
        owner.components.combat.externaldamagemultipliers:SetModifier(inst, mods.damage, inst._baseName .. "bonus")
    end
    if mods.movement and owner.components.locomotor ~= nil then
        owner.components.locomotor:SetExternalSpeedMultiplier(inst, inst._baseName .. "bonus", mods.movement) 
    end
end

local function RemoveModifiers(inst, owner)
    if owner.components.combat ~= nil then
        owner.components.combat.externaldamagemultipliers:RemoveModifier(inst, inst._baseName .. "bonus") 
    end
    if owner.components.locomotor ~= nil then
        owner.components.locomotor:RemoveExternalSpeedMultiplier(inst, inst._baseName .. "bonus") 
    end
end

local postinitfns = 
{
}

local onequipfns = 
{
    luxury_nox_helm = function(inst, owner)
        OnEqipHelm(inst, owner)
        --local mods = {damage = 1.45, movement = 1.25}
        local mods = {damage = 1.15, movement = 1.10}
        SetModifiers(inst, owner, mods)
    end,
}

local onunequipfns = 
{
    luxury_nox_helm = function(inst, owner)
        OnUneqipHelm(inst, owner)
        RemoveModifiers(inst, owner)
    end,
}

local function MakeHat(name, data)
    local build = data.build
    
    local assets = 
    {
        Asset("ANIM", "anim/hat_" .. build .. ".zip"),
    }

    local function common()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(build .. "hat")
        inst.AnimState:SetBuild("hat_" .. build)
        inst.AnimState:PlayAnimation("anim")

        if data.perish then
            inst:AddTag("show_spoilage")
        end
        inst:AddTag("hat")

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inventoryitem")
        if data.image ~= nil then
            inst.components.inventoryitem.atlasname = "images/tfwp_inventoryimgs.xml"
        else
            inst.components.inventoryitem.imagename = "lavaarena_" .. build .. "hat"
        end

        inst:AddComponent("inspectable")

        inst:AddComponent("tradable")

        inst:AddComponent("equippable")
        inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
        inst.components.equippable:SetOnEquip(onequipfns[name] or OnEqipHelm)
        inst.components.equippable:SetOnUnequip(onunequipfns[name] or OnUneqipHelm)

        if data.armor then
            inst:AddComponent("armor")
            inst.components.armor:InitCondition(data.armor[1] or 1000, data.armor[2] or 0.5)
        end

        MakeHauntableLaunch(inst)

        if postinitfns[name] then postinitfns[name](inst) end

        inst._baseName = name
        inst._baseBuild = build

        return inst
    end

    return Prefab("tfwp_".. name.. "_hat", common, assets)
end

local hats = 
{
    luxury_nox_helm = {build = "crowndamager", armor = {1250, 0.85}},
}

local ret = {}

for k, v in pairs(hats) do
    table.insert(ret, MakeHat(k, v))
end

return unpack(ret)