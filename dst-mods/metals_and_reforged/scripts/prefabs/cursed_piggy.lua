local assets = {
	Asset("ANIM", "anim/jiaolian.zip"),
	Asset("ANIM", "anim/jiaolian_idles.zip"),
}
local prefabs = {
    "meat",
	"pigskin",
	--"cursed_piggy_weapon_debuff",
    "cursed_piggy_weapon",
    "cursed_piggy_mask",
}
local tuning = TUNING.TOT.CURSED_PIGGY
--local brain = require("brains/cursed_phantombrain")
local brain = require("brains/cursed_piggybrain")

local sounds = {
    attack = "dontstarve/pig/attack",
    hit    = "dontstarve/pig/hurt",
    death  = "dontstarve/pig/death",
} 

SetSharedLootTable("cursed_piggy", {
    { "meat",                1.00 },
    { "meat",                1.00 },
    { "meat",                1.00} ,
    { "meat",                1.00 },
    { "meat",                1.00 },
    { "meat",                1.00 },
    { "pigskin",             1.00 },
    { "pigskin",             0.70 },
    { "pigskin",             0.33 },
	{ "cursed_piggy_mask",   0.50 },
	{ "cursed_piggy_weapon", 0.50 },
})

local RETARGET_MUST_TAGS = { "_combat", "_health" }
local RETARGET_ONEOF_TAGS = { "player" }
local function RetargetFn(inst)
    return not inst:IsInLimbo()
        and FindEntity(
                inst,
                tuning.TARGET_DIST,
                function(guy)
                    return inst.components.combat:CanTarget(guy)
						and (   guy.components.combat:TargetIs(inst) or
								guy:IsNear(inst, tuning.TARGET_DIST)
							)
                end,
                RETARGET_MUST_TAGS,
                nil,
                RETARGET_ONEOF_TAGS
            )
        or nil
end

local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target)
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
end

local function PhantomsTrigger(inst)
    fns.SpawnPrefabsAroundTarget(inst, "cursed_phantom", 1.5, 2, tuning.PHANTOMS_AMOUNT, 30, 12)
end

local function common(inst)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

	inst.DynamicShadow:SetSize(2.5, 1.5)
    inst.Transform:SetFourFaced()

	MakeCharacterPhysics(inst, 500, 1)

	inst.AnimState:SetBank("jiaolian")
	inst.AnimState:SetBuild("jiaolian")
	inst.AnimState:PlayAnimation("idle", true)

	inst:AddTag("cursed_piggy")
	inst:AddTag("soulless")
    inst:AddTag("pig")

	inst:AddComponent("talker")
	inst.components.talker.fontsize = 35
	inst.components.talker.font = TALKINGFONT_SCAREDCROW
	inst.components.talker.colour = Vector3(255 / 255, 109 / 255, 100 / 255)
	inst.components.talker.offset = Vector3(0, -700, 0)
	inst.components.talker:MakeChatter()

    inst.entity:SetPristine()
	

    if not TheWorld.ismastersim then
        return inst
    end
	
    inst:AddComponent("locomotor")
    inst.components.locomotor.runspeed = tuning.RUNSPEED
    inst.components.locomotor.walkspeed = tuning.WALKSPEED
	
    inst:AddComponent("sanityaura")
    inst.components.sanityaura.aura = -tuning.SANITY_AURA

    inst:AddComponent("health")
	inst.components.health:SetMaxHealth(tuning.HEALTH)
	
    --inst:AddComponent("healthtrigger")
    --inst.components.healthtrigger:AddTrigger(tuning.PHASE3_TRIGGER, PhantomsTrigger)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(tuning.DAMAGE)
    inst.components.combat:SetRange(tuning.ATTACK_RANGE)
    inst.components.combat:SetAttackPeriod(tuning.ATTACK_PERIOD)
    inst.components.combat:SetRetargetFunction(2, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
	
	inst:AddComponent("inspectable")
	
    inst:AddComponent("lootdropper")
	
	inst:AddComponent("knownlocations")
	
	inst.sounds = sounds
    
    --inst.atriumstalker = true --Need this b4 setting brain

	inst:SetBrain(brain)
	inst:SetStateGraph("SGcursed_piggy")
		
    inst:ListenForEvent("attacked", OnAttacked)
	
	MakeSmallBurnableCharacter(inst, "torso")
    MakeSmallFreezableCharacter(inst, "torso")
end

local function original_fn()
    local inst = CreateEntity()

    common(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.components.lootdropper:SetChanceLootTable("cursed_piggy")
	
    return inst
end

return Prefab("cursed_piggy", original_fn, assets, prefabs)