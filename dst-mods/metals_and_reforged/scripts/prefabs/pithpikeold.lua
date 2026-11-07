local assets =
{
    Asset("ANIM", "anim/spear_gungnir.zip"),
    Asset("ANIM", "anim/swap_spear_gungnir.zip"),
}

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object","swap_spear_gungnir","swap_spear_gungnir")
    -------
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function onattack(inst, owner, target)
    local pt = target:GetPosition()
    -------
    local slashfx = SpawnPrefab("jaggedslashfx")
    local shrapnelfx = SpawnPrefab("weaponsparks_piercing")
    -------
    slashfx.Transform:SetPosition(pt.x,1,pt.z)
    -------
    shrapnelfx.Transform:SetPosition(pt.x,1,pt.z)
    shrapnelfx.Transform:SetRotation(owner.Transform:GetRotation() - 90 * math.random(0, 9))
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("spear_gungnir")
    inst.AnimState:SetBuild("spear_gungnir")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("pointy")
    inst:AddTag("weapon")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    -------
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.SPEAR_DAMAGE+25)
    inst.components.weapon.onattack = onattack
    -------
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "spear_gungnir"
    -------
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    inst.components.equippable.walkspeedmult = 1.2
    -------
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(TUNING.SPEAR_USES*2)
    inst.components.finiteuses:SetUses(TUNING.SPEAR_USES*2)
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    -------

    MakeHauntableLaunch(inst)

    return inst
end

local function jaggedslashfxfn(inst)
    local inst = CreateEntity()

    local names = { "line", "curve" }

    inst.animname = names[math.random(#names)]

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.Transform:SetSixFaced()
    inst.Transform:SetRotation(90 * math.random(0, 9))
    inst.Transform:SetScale(2, 2, 2)

    inst.AnimState:SetBank("lavaarena_shadow_lunge_fx")
    inst.AnimState:SetBuild("lavaarena_shadow_lunge_fx")
    inst.AnimState:PlayAnimation(inst.animname)
    inst.AnimState:SetFinalOffset(1)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:ListenForEvent("animover", inst.Remove)
    inst.persists = false

    return inst
end

return Prefab("pithpikeold", fn, assets),
	Prefab( "jaggedslashfx", jaggedslashfxfn, assets)