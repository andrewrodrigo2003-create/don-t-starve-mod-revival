local assets = {}
local prefabs = {
    "shadow_teleport_out",
    "shadow_teleport_in",
}

local tuning = TUNING.TOT.CURSED_PHANTOM
local brain = require("brains/cursed_phantombrain")

local sounds = {
	attack       = "dontstarve/ghost/ghost_howl",
	attack_grunt = "dontstarve/ghost/ghost_girl_howl",
	death        = "dontstarve/pig/werepig_howl",
	idle         = "dontstarve/sanity/knight/idle",
	taunt        = "dontstarve/sanity/knight/die",
	appear       = "dontstarve/sanity/knight/appear",
	disappear    = "dontstarve/sanity/knight/dissappear",
}

local hats = {
    { name = "straw", cover = true },
    { name = "top", cover = true },
    { name = "beefalo", cover = true },
    { name = "feather", cover = true },
    { name = "bee", cover = true },
    { name = "miner", cover = true },
    { name = "spider", cover = true },
    { name = "football", cover = true },
    { name = "earmuffs", cover = false },
    { name = "winter", cover = true },
    { name = "bush", cover = true },
    { name = "flower", cover = false },
    { name = "walrus", cover = true },
    { name = "slurtle", cover = true },
    { name = "ruins", cover = true },
    { name = "mole", cover = true },
    { name = "wathgrithr", cover = true },
    { name = "walter", cover = true },
    { name = "ice", cover = true },
    { name = "rain", cover = true },
    { name = "catcoon", cover = true },
    { name = "watermelon", cover = true },
    { name = "eyebrella", cover = false },
    { name = "red_mushroom", cover = true },
    { name = "green_mushroom", cover = true },
    { name = "blue_mushroom", cover = true },
    { name = "hive", cover = true },
    { name = "dragonhead", cover = true },
    { name = "dragonbody", cover = true },
    { name = "dragontail", cover = true },
    { name = "desert", cover = true },
    { name = "goggles", cover = false },
    { name = "skeleton", cover = true },
    { name = "merm", cover = false },
    { name = "cookiecutter", cover = true },
    { name = "batnose", cover = true },
    { name = "nutrientsgoggles", cover = true },
    { name = "plantregistry", cover = true },
    { name = "balloon", cover = true },
    { name = "alterguardian", cover = false },
}

local armors = {
    "armor_bramble",
    "torso_dragonfly",
    "armor_grass",
    "armor_marble",
    "armor_ruins",
    "armor_sanity",
    "armor_skeleton",
    "armor_slurper",
    "armor_slurtleshell",
    "armor_wood",
}

local weapons = {
    "swap_spear",
    "swap_nightmaresword",
    "swap_nightstick",
    "swap_axe",
    "swap_goldenaxe",
    "swap_pickaxe",
    "swap_goldenpickaxe",
    "swap_spear_wathgrithr",
    "swap_ham_bat",
    "swap_batbat",
    "swap_cane",
}

local function NotifyBrainOfTarget(inst, target)
    if inst.brain ~= nil and inst.brain.SetTarget ~= nil then
        inst.brain:SetTarget(target)
    end
end

local function NormalRetargetFn(inst)
    local maxrangesq = tuning.TARGET_DIST * tuning.TARGET_DIST
    local rangesq, rangesq1, rangesq2 = maxrangesq, math.huge, math.huge
    local target = nil
    for i, v in ipairs(AllPlayers) do
        if not v:HasTag("playerghost") then
            local distsq = v:GetDistanceSqToInst(inst)
            if distsq < rangesq then
                if distsq < rangesq2 and inst.components.combat:CanTarget(v) then
                    target = v
                    rangesq2 = distsq
                    rangesq = math.max(rangesq1, rangesq2)
                end
            end
        end
    end

    return target
end

local RETARGET_MUST_TAGS = { "_combat", "_health" }
local RETARGET_CANT_TAGS = { "player", "friendlyphantom" }
local function FriendlyRetargetFn(inst)
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
                RETARGET_CANT_TAGS,
                nil
            )
        or nil
end

local function ShareTargetFn(dude)
    return dude:HasTag("phantom") and not dude.components.health:IsDead()
end

local function OnAttacked(inst, data)
    inst.components.combat:SetTarget(data.attacker)
    inst.components.combat:ShareTarget(data.attacker, 30, ShareTargetFn, 1)
end

local function OnNewCombatTarget(inst, data)
    NotifyBrainOfTarget(inst, data.target)
end

local function OnDeath(inst, data)
    if data ~= nil and data.afflicter ~= nil and data.afflicter:HasTag("crazy") then
        inst.components.lootdropper:SetLoot({ "nightmarefuel" })
        inst.components.lootdropper:SetChanceLootTable(nil)
    end
end

local function EquipItems(inst, weaponnum, hatnum, armornum)
    inst:AddTag("player")
    SetSkinsOnAnim(inst.AnimState, inst, GetOfficialCharacterList()[math.random(1, #GetOfficialCharacterList())], {})
    inst:RemoveTag("player")
    if not weaponnum then
        weaponnum = math.random(1, #weapons)
    end
    
    if not hatnum then
        hatnum = math.random(1, #hats)
    end

    if not armornum then
        armornum = math.random(1, #armors)
    end  
    local weapondata = weapons[weaponnum]
    local hatdata = hats[hatnum]
    local armordata = armors[armornum]

    if hatdata then
        if math.random() < 0.5 then
            inst.AnimState:OverrideSymbol("swap_hat", "hat_"..hatdata.name, "swap_hat")
            if hatdata.cover then
                inst.AnimState:Show("HAT")
                inst.AnimState:Show("HAIR_HAT")
                inst.AnimState:Hide("HAIR_NOHAT")
                inst.AnimState:Hide("HAIR")
            end
        end
    end
   
    if armordata then
        if math.random() < 0.5 then
            inst.AnimState:OverrideSymbol("swap_body", armordata, "swap_body")
        end
    end

    if weapondata then
        inst.AnimState:OverrideSymbol("swap_object", weapondata, weapondata)
    end
end

local function Erode(inst)
    inst:DoTaskInTime(math.random()*5, function()
        if inst.eroded then
           fns.ReverseErode(inst, 1)
        else
           fns.SafeErode(inst, 1)
        end
        
        inst.eroded = not inst.eroded
        Erode(inst)
    end)
end

local function OnHitOther(inst, data)
    local other = data.target
    if other then
        inst.components.health:DoDelta(-1)
    end
end

local function common_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    --Initialize physics
    local phys = inst.entity:AddPhysics()
    phys:SetMass(1)
    phys:SetFriction(0)
    phys:SetDamping(5)
    phys:SetCollisionGroup(COLLISION.FLYERS)
    phys:ClearCollisionMask()
    phys:CollidesWith(COLLISION.GROUND)
    phys:SetCapsule(0.5, 1)

    inst.Transform:SetFourFaced()

    inst.AnimState:SetBuild("wilson")
    inst.AnimState:SetBank("wilson")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetMultColour(0.35, 0.35, 0.35, 0.35)
    inst.AnimState:UsePointFiltering(true)
    inst.AnimState:Hide("ARM_normal")
    --inst.AnimState:Hide("HAT")
    --inst.AnimState:Hide("HAIR_HAT")
    --inst.AnimState:Show("HAIR_NOHAT")
    --inst.AnimState:Show("HAIR")
    --inst.AnimState:Show("HEAD")
    --inst.AnimState:Hide("HEAD_HAT")

    inst:AddTag("monster")
    inst:AddTag("phantom")
    inst:AddTag("hostile")
    inst:AddTag("notraptrigger")
	inst:AddTag("soulless")
    inst:AddTag("companion")	--test for Big Bernie

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("locomotor")
    inst.components.locomotor.runspeed = tuning.RUNSPEED
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = { ignorecreep = true }
	
    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(tuning.HEALTH)

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(tuning.DAMAGE)
    inst.components.combat:SetAttackPeriod(tuning.ATTACK_PERIOD)
    inst.components.combat:SetPlayerStunlock(PLAYERSTUNLOCK.RARELY)

    inst:ListenForEvent("attacked", OnAttacked)
    inst:ListenForEvent("newcombattarget", OnNewCombatTarget)
    inst:ListenForEvent("death", OnDeath)

    inst.persists = false
    inst.eroded = false

    inst.EquipItems = EquipItems

    inst.sounds = sounds
    inst:SetStateGraph("SGcursed_phantom")

    inst:SetBrain(brain)

    inst:DoTaskInTime(0, EquipItems)

    inst:ListenForEvent("onhitother", OnHitOther)

    return inst
end

local function normal()
    local inst = common_fn()

    if not TheWorld.ismastersim then
        return inst
    end
	
	inst.components.combat:SetRetargetFunction(3, NormalRetargetFn)

	return inst
end

local function friendly()
    local inst = common_fn()

    inst:AddTag("friendlyphantom")

    if not TheWorld.ismastersim then
        return inst
    end
	
	inst.components.combat:SetRetargetFunction(3, FriendlyRetargetFn)
	
	return inst
end

return Prefab("cursed_phantom", normal, assets, prefabs),
    Prefab("cursed_phantom_friendly", friendly, assets, prefabs)