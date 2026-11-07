local _G 				= GLOBAL
local STRINGS 			= _G.STRINGS
local TILE_SCALE 		= _G.TILE_SCALE
local HALF_TILE_SCALE 	= TILE_SCALE / 2.0

if not _G.TheNet:GetIsServer() then
    return
end

simpleregrowth = {
	spawner_spikyrock_frequency = 32,	--48 for 3 days
	spawner_ironrock_frequency = 32,	--2 days
	spawner_rock1_frequency = 32,
	spawner_rock2_frequency = 32,
}

	local prefabcountonground, nonwinterspawners, winteronlyspawners = {}, {}, {}

	local function AddPrefabTracker(prefab, add_counter)
		prefabcountonground[prefab] = 0
		AddPrefabPostInit(prefab, function(ent)
			ent.simpleregrowth = {}
			if add_counter then
				ent.simpleregrowth.add_prefabcountonground = ent:DoTaskInTime(0, function()
				if not ent.components.inventoryitem or not ent.components.inventoryitem.owner then
					prefabcountonground[prefab] = prefabcountonground[prefab] + 1
					ent.simpleregrowth.onground = true
				end
				ent.simpleregrowth.add_prefabcountonground = nil
			end)

			ent:ListenForEvent("onremove", function()
				if ent.simpleregrowth.onground then
					prefabcountonground[prefab] = prefabcountonground[prefab] - 1
				end
				ent.simpleregrowth = nil
			end)

			ent:ListenForEvent("ondropped", function()
				if ent.simpleregrowth.add_prefabcountonground then
					ent.simpleregrowth.add_prefabcountonground:Cancel()
				end
				ent.simpleregrowth.add_prefabcountonground = ent:DoTaskInTime(0, function()
					prefabcountonground[prefab] = prefabcountonground[prefab] + 1
					ent.simpleregrowth.add_prefabcountonground = nil
				end)
				ent.simpleregrowth.onground = true
				ent.simpleregrowth.playerowned = true
			end)

			ent:ListenForEvent("onpickup", function()
				if ent.simpleregrowth.onground then
					prefabcountonground[prefab] = prefabcountonground[prefab] - 1
					ent.simpleregrowth.onground = nil
						if ent.simpleregrowth.playerowned then
							ent.simpleregrowth.playerowned = nil
						end
					end
				end)
			end

			local onsave, onload = ent.OnSave, ent.OnLoad
				ent.OnSave = function(inst, data)
				data.simpleregrowth = {}
				if ent.simpleregrowth.playerowned then
					data.simpleregrowth.playerowned = ent.simpleregrowth.playerowned
				end
				if ent.simpleregrowth.ismodded then
					data.simpleregrowth.ismodded = ent.simpleregrowth.ismodded
				end
				if onsave then
					onsave(inst, data)
				end
			end

			ent.OnLoad = function(inst, data)
				if data and data.simpleregrowth then
					if data.simpleregrowth.playerowned then
						ent.simpleregrowth.playerowned = data.simpleregrowth.playerowned
					end
					if data.simpleregrowth.ismodded then
						ent.simpleregrowth.ismodded = data.simpleregrowth.ismodded
					end
				end
				if onload then
					onload(inst, data)
				end
			end
		end)
	end

	local function TilesAdjacentTo(tilex, tiley, tile, depth)
		local count, searched = 0, {}
		local function deep_search(x, y)
			if not searched[x] then
				searched[x] = {}
			elseif searched[x][y] then
				return
			end
			searched[x][y] = true
			if _G.TheWorld.Map:GetTile(x, y) == tile then
				count = count + 1
				if count < depth then
					deep_search(x - 1, y - 1)
					deep_search(x - 1, y)
					deep_search(x - 1, y + 1)
					deep_search(x, y - 1)
					deep_search(x, y + 1)
					deep_search(x + 1, y - 1)
					deep_search(x + 1, y)
					deep_search(x + 1, y + 1)
				end
			end
		end

		deep_search(tilex, tiley)
		return count
	end

if simpleregrowth.spawner_spikyrock_frequency > 0 then
	AddPrefabTracker("spikyrock", true)
	nonwinterspawners["spikyrock"] = {
		frequency = simpleregrowth.spawner_spikyrock_frequency,
		amount = 10,
		maxcount = 71,
		tile = WORLD_TILES.DESERT_DIRT,
	}
end

if simpleregrowth.spawner_ironrock_frequency > 0 then
	AddPrefabTracker("ironrock", true)
	nonwinterspawners["ironrock"] = {
		frequency = simpleregrowth.spawner_ironrock_frequency,
		amount = 10,
		maxcount = 81,
		tile = WORLD_TILES.ROCKY,
		--GROUND.METEOR, ROCKY
	}
end

if simpleregrowth.spawner_rock1_frequency > 0 then
	AddPrefabTracker("rock1", true)
	nonwinterspawners["rock1"] = {
		frequency = simpleregrowth.spawner_rock1_frequency,
		amount = 10,
		maxcount = 81,
		tile = WORLD_TILES.ROCKY,
	}
end

if simpleregrowth.spawner_rock2_frequency > 0 then
	AddPrefabTracker("rock2", true)
	nonwinterspawners["rock2"] = {
		frequency = simpleregrowth.spawner_rock2_frequency,
		amount = 10,
		maxcount = 81,
		tile = WORLD_TILES.ROCKY,
	}
end

	AddPrefabPostInit(STRINGS.NAMES.MIGRATION_PORTAL and "world" or "forest", function(ent)
		if ent.ismastersim then
			local worldwidth, worldheight, halfworldwidth, halfworldheight, worldsquarelength, tiles, tickage, segage, ticktime, segtime, lastsegused, maxprefabcount = 0, 0, 0, 0, 0, {}, 0, 0, 0, 0, 0, {}

			local function UpdateTime()
				ticktime = math.floor(_G.TheWorld.state.time * TUNING.TOTAL_DAY_TIME + 0.5)
				tickage = math.floor(_G.TheWorld.state.cycles * TUNING.TOTAL_DAY_TIME + 0.5) + ticktime
				segage = math.floor(tickage / TUNING.SEG_TIME + 0.5)
				segtime = math.floor(ticktime / TUNING.SEG_TIME + 0.5)
			end

			local function Spawn(prefab, amount, tile)
				local count = prefabcountonground[prefab]
				local cap = maxprefabcount[prefab]
				if count == nil or cap == nil then
					-- no tracker or no scaled budget for this prefab: spawning would crash on the
					-- comparison below, and there would be nothing to keep the density sane anyway.
					return
				end
				if amount == 0 or count + amount >= cap or not tiles[tile] or #tiles[tile] <= 1 then
					return
				end

				local spawned = 0
				while spawned < amount do
					local idx = math.random(#tiles[tile])
					local tilex, tiley = tiles[tile][idx].tilex, tiles[tile][idx].tiley
					if _G.TheWorld.Map:GetTile(tilex, tiley) ~= tile then
						-- This tile was mapped to the wrong list (the map changed under us, e.g. a
						-- ground tile was replaced by terrain sculpting). Move the entry to the list
						-- of the tile it really is, then pick another candidate.
						--
						-- ORIGINAL BUG: this line read `{ tilex = x, tiley = y }`, but `x` and `y` are
						-- not in scope here, so it inserted an empty table and the next read of
						-- `.tilex` was nil -- GetTile(nil, nil) crashed the spawner for the rest of the
						-- session.
						local realtile = _G.TheWorld.Map:GetTile(tilex, tiley)
						if tiles[realtile] == nil then
							tiles[realtile] = {}
						end
						table.insert(tiles[realtile], { tilex = tilex, tiley = tiley })
						repeat

						table.remove(tiles[tile], idx)
						if #tiles[tile] <= 1 then
							tiles[tile] = nil
							break
						end

						idx = math.random(#tiles[tile])
						tilex, tiley = tiles[tile][idx].tilex, tiles[tile][idx].tiley
						until _G.TheWorld.Map:GetTile(tilex, tiley) == tile
						if not tiles[tile] then
							break
						end
					end

					tilex, tiley = tiles[tile][idx].tilex, tiles[tile][idx].tiley
					local point = _G.Vector3((tilex - halfworldwidth) * TILE_SCALE - HALF_TILE_SCALE + math.random() * TILE_SCALE, 0, (tiley - halfworldheight) * TILE_SCALE - HALF_TILE_SCALE + math.random() * TILE_SCALE)
					-- `spawned_inst`, not `ent`: the outer `ent` is the world entity this closure lives on,
					-- and shadowing it here made the function unreadable (and would break any later code
					-- that needs the world).
					local spawned_inst = _G.SpawnPrefab(prefab)
					if spawned_inst ~= nil then
						spawned_inst.Transform:SetPosition(point:Get())
						spawned = spawned + 1
					else
						break
					end
				end

				if spawned > 0 then
					-- print("[Heap of Foods Regrowth] Spawned ".. spawned.."x of "..prefab.." at seg "..segtime.." (tick: "..ticktime..") of day "..math.floor(tickage / TUNING.TOTAL_DAY_TIME) + 1)
				end
			end

			local function DoNextTick()
				UpdateTime()
				if ticktime % TUNING.SEG_TIME == 0 and segage ~= lastsegused then
					if _G.TheWorld.state.iswinter then
						for prefab, spawner in pairs(winteronlyspawners) do
							if segage % spawner.frequency == 0 then
								Spawn(prefab, math.random(1, spawner.amount), spawner.tile)
							end
						end
					else
						for prefab, spawner in pairs(nonwinterspawners) do
							if segage % spawner.frequency == 0 then
								Spawn(prefab, math.random(1, spawner.amount), spawner.tile)
							end
						end
					end
					lastsegused = segage
				end
			end

			local onsave, onload = ent.OnSave, ent.OnLoad
				ent.OnSave = function(inst, data)
				if lastsegused then
					data.lastsegused = lastsegused
				end
				if onsave then
					onsave(inst, data)
				end
			end

			ent.OnLoad = function(inst, data)
				if data and data.lastsegused then
					lastsegused = data.lastsegused or 0
				end
				-- ORIGINAL BUG: the chained `onload` call sat *inside* the `if data.lastsegused`
				-- block, so loading a world whose save had no recorded seg time skipped whatever
				-- OnLoad the previous mod (or the base prefab) had installed.
				if onload then
					onload(inst, data)
				end
			end

			ent:DoTaskInTime(0, function()
				worldwidth, worldheight = _G.TheWorld.Map:GetSize()
				halfworldwidth, halfworldheight = worldwidth / 2.0, worldheight / 2.0
				worldsquarelength = worldwidth * worldheight
				for x = 0, worldwidth do
					for y = 0, worldheight do
						local tile = _G.TheWorld.Map:GetTile(x, y)
							if not tiles[tile] then
								tiles[tile] = {}
							end
							table.insert(tiles[tile], { tilex = x, tiley = y })
						end
					end
					-- print("[Heap of Foods Regrowth]")
					-- print("   ...World: w: "..worldwidth..", h: "..worldheight..", square length: "..worldsquarelength)

					local function load_prefabs(spawners)
						for prefab, spawner in pairs(spawners) do
						if spawner.amount then
							spawner.amount = math.ceil(spawner.amount / 180625 * worldsquarelength)
						end
						if spawner.maxcount then
							spawner.maxcount = math.ceil(spawner.maxcount /180625 * worldsquarelength)
						end
						if not maxprefabcount[prefab] then
							maxprefabcount[prefab] = spawner.maxcount
							-- print("   ...spawner: "..prefab..": maxcount: "..spawner.maxcount..", amount: "..(spawner.amount or "?")..", current: "..(prefabcountonground[prefab] or "?"))
						end
					end
				end
				load_prefabs(nonwinterspawners)
				load_prefabs(winteronlyspawners)
				ent:DoPeriodicTask(1, function()
					DoNextTick()
				end)
			end)
		end
	end)