local assets =
{
    Asset("ANIM", "anim/sword_buster.zip"),
    Asset("ANIM", "anim/swap_sword_buster.zip"),
}

local RESISTANCES =
{
    "_combat",
}

local function onfinished(inst)
    inst:Remove()
end

local function onattack(inst, attacker, target)

    inst.components.armor:TakeDamage(2)
    local pt = target:GetPosition()
    -------
    local dustfx = SpawnPrefab("round_puff_fx_hi")
    local shrapnelfx = SpawnPrefab("mining_fx")
    -------
    dustfx.Transform:SetScale(.65,.65,.65)
    dustfx.Transform:SetPosition(pt:Get())
    -------
    shrapnelfx.Transform:SetScale(1.5,1.5,1.5)
    shrapnelfx.Transform:SetPosition(pt:Get())
    -------
    inst.SoundEmitter:PlaySound("dontstarve/common/together/catapult/rock_hit", nil, .40)




	local groundpound = SpawnPrefab("groundpoundring_fx")
    local pos = target:GetPosition()
	groundpound.Transform:SetPosition(pos.x, pos.y, pos.z)
	groundpound.Transform:SetScale(0.5, 0.5, 0.5)
	
		local groundpound2 = SpawnPrefab("groundpound_fx")
    local pos = target:GetPosition()
	groundpound2.Transform:SetPosition(pos.x, pos.y, pos.z)
	groundpound2.Transform:SetScale(0.5, 0.5, 0.5)


	local x, y, z = inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, 3, nil, { "playerghost", "player", "FX", "DECOR", "INLIMBO" }, { "animal","character","wall","hostile","monster","insect","spider","epic","ghost" })
	for i, target in ipairs(ents) do
		if target then
			if target.sg and target.components.health then
				if not target.components.health:IsDead() then
					target.sg:GoToState("hit")
					target.components.health:DoDelta(-15)
				end
			end
		end
        end



	
end

local function OnResistDamage(inst, damage)
    local owner = inst.components.inventoryitem:GetGrandOwner() or inst
    local pt = owner:GetPosition()
    local shrapnelfx = SpawnPrefab("mining_fx")
    shrapnelfx.Transform:SetScale(1.5,1.5,1.5)
    shrapnelfx.Transform:SetPosition(pt:Get())
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_sword_buster", "swap_sword_buster")
    -------
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
    owner:AddTag("parrying")
    owner:AddTag("stronggrip")
    inst:ListenForEvent("blocked", OnResistDamage)
    inst:ListenForEvent("attacked", OnResistDamage)

end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    owner:RemoveTag("parrying")
    owner:RemoveTag("stronggrip")
    inst:RemoveEventCallback("blocked", OnResistDamage)
    inst:RemoveEventCallback("attacked", OnResistDamage)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("sword_buster")
    inst.AnimState:SetBuild("sword_buster")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("weapon")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    -------
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(60)
	inst.components.weapon:SetRange(1.6)
    inst.components.weapon.onattack = onattack
    -------
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "lavaarena_heavyblade"
    -------
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(600, .8)
    -------
--[[
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(300)
    inst.components.finiteuses:SetUses(300)
    inst.components.finiteuses:SetOnFinished(onfinished)
]]
    -------
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
    -------
    MakeHauntableLaunch(inst)
    -------
    return inst
end

return Prefab("blacksmith_edgeold", fn, assets, prefabs)
