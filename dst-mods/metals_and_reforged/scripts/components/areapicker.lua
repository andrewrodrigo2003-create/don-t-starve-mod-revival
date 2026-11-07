local AreaPicker = Class(function(self, inst)
	self.inst = inst
	self.radius = 4						--harvest radius; 1 turf wide = 4 unit
	self.radius_multiplyer = 2			--honey seasoning multiplyer; double the radius by default
	self.radius_fn = nil				--allow you to further modify the havest radius

	self.picker = {"readyforharvest"}
	self.pick_after_fn = {}				--function after picking;	eg. "FastGrowth" in this mod 
	self.pick_before_fn = {}			--function before picking;	eg. "ExtraItem" and "ExtraPicks" in this mod
	self.pick_while_fn = {}				--other custom picking fn.	For other items which have other component actions

	self.inst:AddTag("areapicker")
	if self.inst.components.finiteuses ~= nil and self.inst.components.finiteuses.consumption[ACTIONS.AREAPICK] == nil then
		self.inst.components.finiteuses:SetConsumption(ACTIONS.AREAPICK, 1)
	end
end)

function AreaPicker:OnRemoveFromEntity()
	self.inst:RemoveTag("areapicker")
	if self.inst.components.finiteuses ~= nil then
		self.inst.components.finiteuses:SetConsumption(ACTIONS.AREAPICK)
	end
end

function AreaPicker:SetRadius(radius, seasoning_mult)
	self.radius = radius
	if seasoning_mult then
		self.radius_multiplyer = seasoning_mult
	end
end

function AreaPicker:SetRadiusFn(fn)
	self.radius_fn = fn					--arg: radius, doer, target, self.inst
end

function AreaPicker:SetPicker(tags)		--remember to add "readyforharvest" tag so that it can harvest farmplot crops;
	self.picker = tags					--I do not add the tag here so that you can leave it blank to make it unable to harvest them
end

function AreaPicker:AddPicker(tags)
	if type(tags) == "table" then
		for i, v in ipairs(tags) do
			table.insert(self.picker, v)
		end
	elseif type(tags) == "string" then
		table.insert(self.picker, tags)
	end
end

function AreaPicker:RemovePicker(tag)
	for i, v in ipairs(self.picker) do
		if v == tag then
			table.remove(self.picker, i)
		end
	end
end

function AreaPicker:AddPickerByPrefab(prefab)
	if self.pickerbyprefab == nil then
		self.pickerbyprefab = {}
	end
	if type(prefab) == "table" then
		for i, v in ipairs(prefab) do
			self.pickerbyprefab[v] = true
		end
	elseif type(prefab) == "string" then
		self.pickerbyprefab[prefab] = true
	end
end

function AreaPicker:RemovePickerByPrefab(prefab)
	self.pickerbyprefab[prefab] = nil
end

function AreaPicker:SetFn(key, fn, fn_type)						--fn_type: (before: 0  while: 1  after: 2)
	if string.find(fn_type, "a") or fn_type == 2 then			--arg: (doer, target, self.inst)
		self.pick_after_fn[key] = fn
	elseif string.find(fn_type, "b") or fn_type == 0 then
		self.pick_before_fn[key] = fn
	else
		self.pick_while_fn[key] = fn
	end
end

function AreaPicker:RemoveFnByKey(key, fn_type)
	if key == nil or fn_type == nil then return end
	if string.find(fn_type, "a") or fn_type == 2 then
		self.pick_after_fn[key] = nil
	elseif string.find(fn_type, "b") or fn_type == 0 then
		self.pick_before_fn[key] = nil
	else
		self.pick_while_fn[key] = nil
	end
end

local PICK_MUST_TAG = {"plant", "pickable"}
local PICK_MUSTNOT_TAG = {"notreadyforharvest", "stump", "withered", "barren", "FX", "NOCLICK", "DECOR", "INLIMBO"}
function AreaPicker:Pick(doer, target)
	local x, y, z = doer.Transform:GetWorldPosition()

	local base_radius = self.radius * (doer.components.debuffable:HasDebuff("buff_workeffectiveness") and self.radius_multiplyer or 1)		--double the radius if doer has honey seasoning buff
	local radius, ignore_buff = self.radius_fn ~= nil and self.radius_fn(base_radius, doer, target, self.inst) or base_radius
	if doer.components.workmultiplier ~= nil then
		radius = radius * doer.components.workmultiplier:GetMultiplier(ACTIONS.AREAPICK)
	end
	radius = ignore_buff and base_radius or radius

	local ents = TheSim:FindEntities(x, y, z, radius, PICK_MUST_TAG, PICK_MUSTNOT_TAG)
	--for old version farm plot	--and other pickable you want
	if self.picker ~= nil and #self.picker ~= 0 then
		local crop = TheSim:FindEntities(x, y, z, radius, nil, PICK_MUSTNOT_TAG, self.picker)
		for i, v in ipairs(crop) do
			if v:HasTag("pickable") or v:HasTag("takeshelfitem") or v:HasTag("readyforharvest") then
				table.insert(ents, v)
			end
		end
	end

	if self.pickerbyprefab ~= nil and #self.pickerbyprefab ~= 0 then
		local extra_targ = TheSim:FindEntities(x, y, z, radius, nil, PICK_MUSTNOT_TAG)
		for i, v in ipairs(extra_targ) do
			if self.pickerbyprefab[v.prefab] then
				table.insert(ents, v)
			end
		end
	end

	if self.radius == 0 then
		ents = {target}
	end

	local collected = 0
	local finiteuses = self.inst.components.finiteuses
	local uses = finiteuses ~= nil and (finiteuses:GetUses() / finiteuses.consumption[ACTIONS.AREAPICK]) or 255
	for i, ent in ipairs(ents) do
		if collected >= uses then break end

		for k, fn in pairs(self.pick_before_fn) do
			fn(doer, ent, self.inst)
		end

		if ent.components.pickable ~= nil then
			ent.components.pickable:Pick(doer)

		elseif ent.components.crop ~= nil then			--for farm plant
			ent.components.crop:Harvest(doer)

		elseif ent.components.shelf ~= nil then			--for lureplant
			ent.components.shelf:TakeItem(doer)
		else
			for id, fn in pairs(self.pick_while_fn) do	--for custom pick action
				if ent.components[id] ~= nil then
					fn(doer, ent, self.inst)
					collected = collected + 1
					break
				end
			end
			collected = collected - 1					--if cannot be picked
		end

		for k, fn in pairs(self.pick_after_fn) do
			fn(doer, ent, self.inst)
		end

		collected = collected + 1
	end

	if collected >= 1 then
		if finiteuses ~= nil then
			local uses = (collected - 1) * finiteuses.consumption[ACTIONS.AREAPICK]				--(collected-1) because when the action done, it consume 1 uses
			if doer.components.efficientuser ~= nil then
				uses = uses * (doer.components.efficientuser:GetMultiplier(ACTIONS.AREAPICK) or 1)
			end
			finiteuses:Use(uses)
		end

        self.inst:PushEvent("onareapickfinished", {doer = doer, collected = collected})

		--clear the collision between the player and the oversized crops for 3 seconds
		doer.Physics:ClearCollidesWith(COLLISION.SMALLOBSTACLES)
		doer:DoTaskInTime(3, function(doer)
			doer.Physics:CollidesWith(COLLISION.SMALLOBSTACLES)
		end)

		return true
	end

	return false
end

return AreaPicker