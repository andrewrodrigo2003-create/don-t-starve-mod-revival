local STRINGS = GLOBAL.STRINGS
local GROUND = GLOBAL.GROUND
local require = GLOBAL.require

STRINGS.ACTIONS.AREAPICK = "Harvest"

local tuning = {
	HARVEST_RADIUS = 4,	--default = 6
}

TUNING.SHEARS = tuning

local function AddModConfigTag(prefix, tags)	
	local config = GLOBAL.KnownModIndex:GetModConfigurationOptions_Internal(modname, true)
	local tags = tags ~= nil and tags or {}
	if config and type(config) == "table" then
		for k, v in pairs(config) do
			if string.find(v.name, prefix) and (v.saved ~= nil and v.saved or v.default) then
				table.insert(tags, string.lower(string.sub(v.name, string.len(prefix)+1)))
			end
		end
	end
	return tags
end

local PICKER_TAG = AddModConfigTag("PICKER_", {"readyforharvest"})
local function TargetHasTag(target, tags)
	for i, v in ipairs(PICKER_TAG) do
		if target:HasTag(v) then
			return target:HasTag("pickable")
				or target:HasTag("takeshelfitem")
				or (v == "readyforharvest")
		end
	end

	return false
end


local function TargetDist(doer, target)
	if target == nil then
		return
	end
	local target_x, target_y, target_z = target.Transform:GetWorldPosition()
	local doer_x, doer_y, doer_z = doer.Transform:GetWorldPosition()
	local dst = GLOBAL.distsq(target_x, target_z, doer_x, doer_z)
	return dst
end

--------Action--------
local function DefaultRangeCheck(doer, target)
	if target == nil then
		return
	end
	local dst = TargetDist(doer, target)
	return dst <= 16
end

local function ExtraPickupRange(doer, dest)
	if dest ~= nil then
		local target_x, target_y, target_z = dest:GetPoint()

		local is_on_water = GLOBAL.TheWorld.Map:IsOceanTileAtPoint(target_x, 0, target_z) and not GLOBAL.TheWorld.Map:IsPassableAtPoint(target_x, 0, target_z)
		if is_on_water then
			return 0.75
		end
	end
    return 0
end

local AREAPICK = AddAction("AREAPICK", STRINGS.ACTIONS.AREAPICK, function(act)
	local equip = act.invobject or act.doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	if act.doer ~= nil and act.target ~= nil and equip ~= nil and equip.components.areapicker ~= nil then
		equip.components.areapicker:Pick(act.doer, act.target)
		return true
	end
end)

AREAPICK.priority = .1
AREAPICK.canforce = true
AREAPICK.rangecheckfn = DefaultRangeCheck
AREAPICK.extra_arrive_dist = ExtraPickupRange
AREAPICK.mount_valid = true

AddComponentAction("USEITEM", "areapicker", function(inst, doer, target, actions, right)
	if inst:HasTag("areapicker") and (target:HasTag("plant") and target:HasTag("pickable") or TargetHasTag(target)) then
		table.insert(actions, AREAPICK)
	end
end)

AddComponentAction("EQUIPPED", "areapicker", function(inst, doer, target, actions)
	if inst:HasTag("areapicker") and (target:HasTag("plant") and target:HasTag("pickable") or TargetHasTag(target)) then
		table.insert(actions, AREAPICK)
	end
end)

local ActionHandler = GLOBAL.ActionHandler
AddStategraphActionHandler("wilson", ActionHandler(AREAPICK, "shearsharvest"))
AddStategraphActionHandler("wilson_client", ActionHandler(AREAPICK, "shearsharvest"))	--"dojostleaction"


for k, v in pairs({"shears"}) do
	AddPrefabPostInit(v, function(inst)
		if not GLOBAL.TheWorld.ismastersim then return end
		inst.components.areapicker:SetPicker(PICKER_TAG)
	end)
end

--------PlayerController--------
AddComponentPostInit("playercontroller", function(self)
	local OLD_GetActionButtonAction = self.GetActionButtonAction

	local PICK_MUSTNOT_TAG = {"notreadyforharvest", "stump", "withered", "barren", "NOCLICK", "INLIMBO"}
	local PICK_ONEOF_TAG = AddModConfigTag("PICKER_", {"plant", "readyforharvest"})	
	local function New_GetActionButtonAction(self, force_target)
		if not (
			((not self.ismastersim and (self.remote_controls[GLOBAL.CONTROL_ACTION] or 0) > 0)
				or not self:IsEnabled()
				or self:IsBusy()
				or (force_target ~= nil and (not force_target.entity:IsVisible() or force_target:HasTag("INLIMBO") or force_target:HasTag("NOCLICK"))))
			or (self.inst.replica.inventory:IsHeavyLifting() and not (self.inst.replica.rider ~= nil and self.inst.replica.rider:IsRiding()))
		) and not self:IsDoingOrWorking() and not self.inst:HasTag("playerghost") then

			local tool = self.inst.replica.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS)
			if tool ~= nil and tool:HasTag("areapicker") or self.inst.replica.inventory:HasItemWithTag("areapicker", 1) then
				local x, y, z = self.inst.Transform:GetWorldPosition()
				local radius = math.clamp(self.directwalking and 3 or 6, TUNING.SHEARS.HARVEST_RADIUS + 2, 10)
				local ents = GLOBAL.TheSim:FindEntities(x, y, z, radius, nil, PICK_MUSTNOT_TAG, PICK_ONEOF_TAG)
				for i, target in pairs(ents) do
					if target:HasTag("smolder") then
						return GLOBAL.BufferedAction(self.inst, target, GLOBAL.ACTIONS.SMOTHER)
					elseif (target:HasTag("plant") and target:HasTag("pickable") or TargetHasTag(target)) then
						if tool ~= nil and tool:HasTag("areapicker") then
							return GLOBAL.BufferedAction(self.inst, target, AREAPICK, tool)
						elseif GLOBAL.KnownModIndex:IsModEnabled("workshop-651419070") then
							local items = self.inst.replica.inventory:GetItems()
							local item
							for k, v in pairs(items) do
								if v:HasTag("areapicker") then
									item = v
									break
								end
							end
							if self.autoequip_lastequipped ~= nil then
								self.autoequip_lastequipped = tool ~= nil and tool or "empty"
							end
							if item ~= nil then
								self.inst.replica.inventory:UseItemFromInvTile(item)
								return GLOBAL.BufferedAction(self.inst, target, AREAPICK, item)
							end
						end
					end
				end				
			end
		end
	end

	function self:GetActionButtonAction(force_target)
		local old_action = not self:IsDoingOrWorking() and OLD_GetActionButtonAction(self, force_target) or nil
		local new_action = New_GetActionButtonAction(self, force_target)
		if old_action ~= nil and new_action ~= nil then
			local old_dist = TargetDist(old_action.doer, old_action.target) or 0
			local new_dist = TargetDist(new_action.doer, new_action.target)
			if old_dist >= new_dist then
				return new_action
			else
				return old_action
			end
		else
			return new_action ~= nil and new_action or old_action
		end
	end
end)

--------ActtionQueuer--------
AddComponentPostInit("actionqueuer", function(self)
	if self.AddAction ~= nil then
		self.AddAction("allclick", "AREAPICK", true)
		self.AddAction("tools", "AREAPICK", true)
		self.AddAction("autocollect", "AREAPICK", true)
	end
end)

-----------------------------------------------------------------------------------------------------
--Custom anim

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

local function DoMountSound(inst, mount, sound, ispredicted)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, ispredicted)
    end
end

local function DoMountSoundClient(inst, mount, sound)
    if mount ~= nil and mount.sounds ~= nil then
        inst.SoundEmitter:PlaySound(mount.sounds[sound], nil, nil, true)
    end
end

--{ Shears Harvesting }--
	local shearsharvest = State({
        name = "shearsharvest",
        tags = { "doing", "notalking", "working" },	--"doing", "notalking"
        onenter = function(inst)
            local buffaction = inst:GetBufferedAction()
            local target = buffaction ~= nil and buffaction.target or nil
            local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
            inst.components.locomotor:Stop()
            if equip ~= nil and equip:HasTag("shears") then
 		inst.SoundEmitter:PlaySound("turnoftides/common/together/boat/jump")
 		inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/items/weapon/halberd")
                inst.AnimState:PlayAnimation("cut_loop")
                inst.AnimState:PushAnimation("cut_pst")
                cooldown = 0.75
            end

            inst.sg:SetTimeout(cooldown)

            if target ~= nil then
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
		local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		if equip ~= nil and equip:HasTag("shears") then
			if equip.components.finiteuses then
				if equip.uses then
					equip.uses = equip.uses - 1
					equip.components.finiteuses:SetUses(equip.uses)
				end
			end
		end
            end),
        },

        ontimeout = function(inst)
            inst.sg:AddStateTag("idle")
	    inst.sg:GoToState("idle")
        end,

        events =
        {
            EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
            EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
        },

        onexit = function(inst)

        end,
    }
)
AddStategraphState("wilson", shearsharvest)

local shearsharvest_client = State({
	name = "shearsharvest",
        tags = { "doing", "notalking", "working" },	--"doing", "notalking"
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
                    cooldown = math.max(cooldown, 16 * FRAMES)
                end
            elseif equip ~= nil and equip:HasTag("shears") then
                inst.AnimState:PlayAnimation("cut_loop")
                inst.AnimState:PushAnimation("cut_pst")
                if cooldown > 0 then
			cooldown = 0.75
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
            end),
        },

        ontimeout = function(inst)
            inst.sg:AddStateTag("idle")
	    inst.sg:GoToState("idle")
        end,

        onexit = function(inst)

        end,
	}
)
AddStategraphState("wilson_client", shearsharvest_client)