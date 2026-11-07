local function ReverseErode(inst, erode_time, erodeparam1, erodeparam2)
	local time_to_erode = erode_time or 1
    local tick_time = TheSim:GetTickTime()

    inst:StartThread(function()
        local ticks = 0
        while ticks * tick_time < time_to_erode do
            local erode_amount = ticks * tick_time / time_to_erode
            inst.AnimState:SetErosionParams(1 - erode_amount, erodeparam1 or 0.1, erodeparam2 or 1.0)
            ticks = ticks + 1
            Yield()
        end
		inst.AnimState:SetErosionParams(0, erodeparam1 or 0, erodeparam2 and -1.0 or 0)
    end)
end

local function SafeErode(inst, erode_time, erodeparam1, erodeparam2)
	local time_to_erode = erode_time or 1
    local tick_time = TheSim:GetTickTime()

    inst:StartThread(function()
        local ticks = 0
        while ticks * tick_time < time_to_erode do
            local erode_amount = ticks * tick_time / time_to_erode
            inst.AnimState:SetErosionParams(erode_amount, erodeparam1 or 0.1, erodeparam2 or 1.0)
            ticks = ticks + 1
            Yield()
        end
		inst.AnimState:SetErosionParams(1, erodeparam1 or 0, erodeparam2 or 1.0)
    end)
end

local function SpawnPrefabsAroundTarget(target, prefab, min_delay, max_delay, prefabs_amount, maxradius, attempts)
	local spawned = {}
	local pt = target:GetPosition()
	local MIN_DELAY = min_delay or 1.5
	local MAX_DELAY = max_delay or 2
	local PREFABS_AMOUNT = prefabs_amount or 1
	local attempts = attempts or 12
	
	for i = 1, PREFABS_AMOUNT do
		target:DoTaskInTime(MIN_DELAY * math.random() + MAX_DELAY / i, function()
			local theta = math.random() * 2 * PI
			local radius = math.random(2, maxradius)	
			local result_offset = FindValidPositionByFan(theta, radius, attempts, function(offset)
				local pos = pt + offset
				return TheWorld.Map:IsPassableAtPoint(pos:Get()) and TheWorld.Map:IsDeployPointClear(pos, nil, 1)
			end)
		
			if result_offset ~= nil then							
				local x, z = pt.x + result_offset.x, pt.z + result_offset.z
				local pref = SpawnPrefab(prefab)
				pref.Transform:SetPosition(x, 0, z)
				table.insert(spawned, pref)
			end
		end)
	end
	return spawned or {}
end

local function SpawnPrefabsInCircle(inst, prefab, n, radius)
	local spawned = {}
	local x, y, z = inst.Transform:GetWorldPosition()

	for i = 1, n do
		local a = i / n * 2 * PI
		local pos = Vector3(x + math.cos(a) * radius, 0, z + math.sin(a) * radius)
		local pref = SpawnAt(prefab, pos)
		table.insert(spawned, pref)
	end
	
	return spawned
end

local function OnLaunchItem(item, angle)
    local speed = math.random() * 4 + 3
    angle = (angle + math.random() * 60 - 30) * DEGREES
    item.Physics:SetVel(speed * math.cos(angle), math.random() * 2 + 8, speed * math.sin(angle))
end

local function DropItem(inst, prefab, lootbeacon)
	local item = SpawnPrefab(prefab)

	if item == nil then
		return
	end

	local x, y, z = inst:GetPosition():Get()
	y = 4.5

	local angle

	local down = TheCamera:GetDownVec()
	angle = math.atan2(down.z, down.x) / DEGREES

	item.Transform:SetPosition(x, y, z)

	if item.components.inventoryitem then
		item.components.inventoryitem:DoDropPhysics(x, y, z, true, 1.1)
	
		OnLaunchItem(item, angle)
	    
		if lootbeacon then
			local lootbeacon = SpawnPrefab("lootbeacon")
			lootbeacon:SetTarget(item)
		end
	end
end

local function TeleportPrefabsInCircle(inst, prefabs, radius)
	local count = #prefabs
	local x, y, z = inst.Transform:GetWorldPosition()
	local theta = math.random() * PI * 2

	for i=1, count do
		local a = i/count * PI * 2 + theta
		local pref = prefabs[i]

		if pref:HasTag("player") and pref.Physics then
			pref.Physics:Teleport(x + math.cos(a) * radius, 0, z + math.sin(a) * radius)
		else
			pref.Transform:SetPosition(x + math.cos(a) * radius, 0, z + math.sin(a) * radius)
		end	

        if pref.components.leader ~= nil then
            for follower, v in pairs(pref.components.leader.followers) do
                a = math.random() * PI * 2

				if follower:HasTag("player") and follower.Physics then
					follower.Physics:Teleport(x + math.cos(a) * radius*2, 0, z + math.sin(a) * radius * 2)
				else
					follower.Transform:SetPosition(x + math.cos(a) * radius * 2, 0, z + math.sin(a) * radius * 2)
				end
            end
        end
	end	
end

local function MakeDecor(inst)
	inst:AddTag("DECOR")
	inst:AddTag("NOCLICK")
	
	for k, v in pairs(inst.components) do
		inst:RemoveComponent(tostring(k))
	end
end

return {
    ReverseErode = ReverseErode,
	SafeErode = SafeErode,
	SpawnPrefabsAroundTarget = SpawnPrefabsAroundTarget,
	SpawnPrefabsInCircle = SpawnPrefabsInCircle,
	OnLaunchItem = OnLaunchItem,
	DropItem = DropItem,
	TeleportPrefabsInCircle = TeleportPrefabsInCircle,
	MakeDecor = MakeDecor,
}