local FRAMES = GLOBAL.FRAMES
local ACTIONS = GLOBAL.ACTIONS
local State = GLOBAL.State
local EventHandler = GLOBAL.EventHandler
local ActionHandler = GLOBAL.ActionHandler
local TimeEvent = GLOBAL.TimeEvent
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local require = GLOBAL.require
local SpawnPrefab = GLOBAL.SpawnPrefab
local TheSim = GLOBAL.TheSim
local GetString = GLOBAL.GetString

local require = GLOBAL.require
local STRINGS = GLOBAL.STRINGS
local RECIPETABS = GLOBAL.RECIPETABS
local CUSTOM_RECIPETABS = GLOBAL.CUSTOM_RECIPETABS
local Recipe = GLOBAL.Recipe
local Recipes = GLOBAL.AllRecipes
local TECH = GLOBAL.TECH
local Vector3 = GLOBAL.Vector3
local Ingredient = GLOBAL.Ingredient
local FOODTYPE = GLOBAL.FOODTYPE

local function DoAMountSound(inst, mount, sound, ispredicted)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, ispredicted)
    end
end

local function DoAMountSoundForClient(inst, mount, sound)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, true)
    end
end

local function OnFinished(inst)
    inst:Remove()
end

local heavyattack= State({
        name = "heavyattack",
        tags = { "attack", "notalking", "abouttoattack", "autopredict" },
        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst.components.combat:SetTarget(target)
            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            local cooldown = inst.components.combat.min_attack_period + .5 * FRAMES
            if inst.components.rider ~= nil and inst.components.rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSound(inst, inst.components.rider:GetMount(), "angry", true)
                cooldown = math.max(cooldown, 20 * FRAMES)
            elseif equip ~= nil and equip:HasTag("heavyattack") then
                inst.AnimState:PlayAnimation("pickaxe_loop")
		inst.AnimState:PushAnimation("pickaxe_pst", false)
                inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
                cooldown = math.max(cooldown, 13 * FRAMES)
            end

            inst.sg:SetTimeout(cooldown)

            if target ~= nil then
                inst.components.combat:BattleCry()
                if target:IsValid() then
                    inst:FacePoint(target:GetPosition())
                    inst.sg.statemem.attacktarget = target
                end
            end
        end,

        timeline =
        {
            TimeEvent(4 * FRAMES, function(inst)
                inst:PerformBufferedAction()
                inst.sg:RemoveStateTag("abouttoattack")
		inst.SoundEmitter:PlaySound("dontstarve/wilson/hit")
            end),
            TimeEvent(0.75, function(inst)
		if not inst.components.health:IsDead() then
			inst.sg:GoToState("heavyparry")
		end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            inst.components.combat:SetTarget(nil)
            if inst.sg:HasStateTag("abouttoattack") then
                inst.components.combat:CancelAttack()
            end
        end,
    }
)

AddStategraphState("wilson", heavyattack)

local heavyattack_client = State({
	name = "heavyattack",
        tags = { "attack", "notalking", "abouttoattack" },
        onenter = function(inst)
            local cooldown = 0
            if inst.replica.combat ~= nil then
                inst.replica.combat:StartAttack()
                cooldown = inst.replica.combat:MinAttackPeriod() + .5 * FRAMES
            end
            inst.components.locomotor:Stop()
            local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            local rider = inst.replica.rider
            if rider ~= nil and rider:IsRiding() then
                inst.AnimState:PlayAnimation("atk_pre")
                inst.AnimState:PushAnimation("atk", false)
                DoMountSoundClient(inst, rider:GetMount(), "angry")
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 20 * FRAMES)
                end
            elseif equip ~= nil and equip:HasTag("heavyattack") then
                inst.AnimState:PlayAnimation("pickaxe_loop")
		inst.AnimState:PushAnimation("pickaxe_pst", false)
                if cooldown > 0 then
                    cooldown = math.max(cooldown, 13 * FRAMES)
                end
            end

            local buffaction = inst:GetBufferedAction()
            if buffaction ~= nil then
                inst:PerformPreviewBufferedAction()

                if buffaction.target ~= nil and buffaction.target:IsValid() then
                    inst:FacePoint(buffaction.target:GetPosition())
                    inst.sg.statemem.attacktarget = buffaction.target
                end
            end

            if cooldown > 0 then
                inst.sg:SetTimeout(cooldown)
            end
        end,

        timeline =
		{
            TimeEvent(4 * FRAMES, function(inst)
                    inst:ClearBufferedAction()
                    inst.sg:RemoveStateTag("abouttoattack")
	    end),
            TimeEvent(0.75, function(inst)
		--if inst.components.health then
			--if not inst.components.health:IsDead() then
				inst.sg:GoToState("heavyparry")
			--end
		--end
            end),
        },

        ontimeout = function(inst)
            inst.sg:RemoveStateTag("attack")
            inst.sg:AddStateTag("idle")
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },

        onexit = function(inst)
            if inst.sg:HasStateTag("abouttoattack") and inst.replica.combat ~= nil then
                inst.replica.combat:CancelAttack()
            end
        end,
	}
)

AddStategraphState("wilson_client", heavyattack_client)

local function HeavyWeapon(inst)
	inst:AddTag("heavyattack")
	inst.entity:AddSoundEmitter()
end
AddPrefabPostInit("blacksmith_edge", HeavyWeapon)
AddPrefabPostInit("blacksmith_edgeold", HeavyWeapon)



AddStategraphActionHandler("wilson",
	ActionHandler(ACTIONS.ATTACK,
        function(inst, action)
            inst.sg.mem.localchainattack = not action.forced or nil
            if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or inst.components.health:IsDead()) then
		local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                return (weapon == nil and "attack")
					or (weapon:HasTag("heavyattack") and "heavyattack")
					or "attack"
        end
end))

-- Client Side
AddStategraphActionHandler("wilson_client",
	ActionHandler(ACTIONS.ATTACK,
        function(inst, action)
            if not (inst.sg:HasStateTag("attack") and action.target == inst.sg.statemem.attacktarget or inst.replica.health:IsDead()) then
                local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                if equip == nil then
                    return "attack"
                end
                local inventoryitem = equip.replica.inventoryitem
                return (not (inventoryitem ~= nil and inventoryitem:IsWeapon()) and "attack")
					or (equip:HasTag("heavyattack") and "heavyattack")
                    or "attack"
            end
end))
