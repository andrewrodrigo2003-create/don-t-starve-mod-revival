require = GLOBAL.require
TUNING = GLOBAL.TUNING
Vector3 = GLOBAL.Vector3
SpawnPrefab = GLOBAL.SpawnPrefab

local function spawnoffscreen(pt, radius)
	local theta = math.random() * 2 * GLOBAL.PI
	radius = radius or 40
	local offset = GLOBAL.FindWalkableOffset(pt, theta, radius, 12, true)
	if offset then
		return pt+offset
	end
end

function spawnattacker(prefab, teleporttoinst, guy)
	teleporttoinst=teleporttoinst or false
	local pt = Vector3(guy.Transform:GetWorldPosition())
	local spawn_pt = spawnoffscreen(pt)
	if spawn_pt and prefab then
		local attacker = SpawnPrefab(prefab)
		if attacker and teleporttoinst==true then
			spawn_pt = Vector3(guy.Transform:GetWorldPosition())
			attacker.Physics:Teleport(spawn_pt:Get())
		end
		if attacker and attacker.Physics and attacker.components.combat then
			attacker:FacePoint(pt)
			attacker.Physics:Teleport(spawn_pt:Get())
			attacker:DoTaskInTime(1, function(attacker)
				if attacker.components.knownlocations then
					attacker.components.knownlocations.locations["home"]=Vector3(guy.Transform:GetWorldPosition())
				end
			end)
			if attacker.components.sleeper and attacker.components.sleeper.isasleep then
				attacker.components.sleeper:WakeUp()
			end
			attacker.components.combat:SetTarget(guy)
		end
	end
end

AddPlayerPostInit(function(inst)
	inst:ListenForEvent("onattackother", function(inst, data)
		--if data.target.prefab == "crawlinghorror" then
			--if math.random() > 0.25 then
				--spawnattacker("cursed_phantom", false, inst)
			--end
		--end
		if GetModConfigData("cursedpig") then
		if data.target.prefab == "pigman" then
			if math.random() < 0.02 then
				spawnattacker("cursed_piggy", false, inst)
			end
		end
		end
	end)
end)