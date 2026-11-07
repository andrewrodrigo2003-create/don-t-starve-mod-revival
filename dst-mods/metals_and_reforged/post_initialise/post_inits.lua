local next = GLOBAL.next
local TheNet = GLOBAL.TheNet
local GROUND = GLOBAL.GROUND
local TUNING = GLOBAL.TUNING
local require = GLOBAL.require
local ACTIONS = GLOBAL.ACTIONS
local DEGREES = GLOBAL.DEGREES
local STRINGS = GLOBAL.STRINGS
local TheWorld = GLOBAL.TheWorld
local SpawnPrefab = GLOBAL.SpawnPrefab
local SPECIAL_EVENTS = GLOBAL.SPECIAL_EVENTS
local SKIN_FX_PREFAB = GLOBAL.SKIN_FX_PREFAB
local resolvefilepath = GLOBAL.resolvefilepath
local IsSpecialEventActive = GLOBAL.IsSpecialEventActive 
local AwardPlayerAchievement = GLOBAL.AwardPlayerAchievement

--TUNING.AXE_USES = TUNING.AXE_USES * 3
--TUNING.PICKAXE_USES = TUNING.PICKAXE_USES * 4.5
--TUNING.SHOVEL_USES = TUNING.SHOVEL_USES * 3

local function IronTools()
	local statues = {"axe", "pickaxe", "shovel"}

	for i, v in pairs(statues) do
		AddPrefabPostInit(v, function(inst)
			inst:AddTag("ironmetal")
		end)
	end
end

IronTools()