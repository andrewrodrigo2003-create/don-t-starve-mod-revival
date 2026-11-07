local State = GLOBAL.State
local Action = GLOBAL.Action
local FRAMES = GLOBAL.FRAMES
local require = GLOBAL.require
local ACTIONS = GLOBAL.ACTIONS
local TheInput = GLOBAL.TheInput
local TimeEvent = GLOBAL.TimeEvent
local SpawnPrefab = GLOBAL.SpawnPrefab
local TOOLACTIONS = GLOBAL.TOOLACTIONS
local EventHandler = GLOBAL.EventHandler
local ActionHandler = GLOBAL.ActionHandler
local CONTROL_ACTION = GLOBAL.CONTROL_ACTION
local CONTROL_CONTROLLER_ACTION = GLOBAL.CONTROL_CONTROLLER_ACTION

-- Marcador proprio do componente smelter (antes o codigo testava "hasingot",
-- que nunca era definido em lugar nenhum, e por isso a colher do produto
-- pronto so aparecia por acidente).
local READY_TAG = "mam_readytoharvest"

AddAction(
	"SMELT",
	"Smelt",
	function(act)
		if act.target and act.target.components.smelter then
			local smelter = act.target.components.smelter

			if smelter.canharvest then
				-- Tem produto aguardando: precisa colher antes de recarregar.
				return false
			end

			return smelter:StartSmelting(act.doer) and true or false
		end
	end)


-- Smelting

AddComponentAction("SCENE", "smelter", function(inst, doer, actions, right)
	if inst:HasTag(READY_TAG) then
		table.insert(actions, ACTIONS.HARVEST)
	end
end)

local OldHarvestfn = ACTIONS.HARVEST.fn

ACTIONS.HARVEST.fn = function(act, ...)
	if act.target ~= nil and act.target.components.smelter ~= nil then
		if act.target:HasTag(READY_TAG) then
			act.target.components.smelter:Harvest(act.doer)

			return true
		end
	--elseif act.target.components.newcrop ~= nil then
		--if act.target ~= nil and not act.target:HasTag("notreadyforharvest") then
			--return act.target.components.newcrop:Harvest(act.doer) and true or false
		--end
	end

	-- Qualquer outro entity (inclusive outros mods) segue a colheita vanilla.
	--
	-- `...` precisa ser reencaminhado: Uncompromising Mode Beta embrulha esta mesma
	-- funcao (init/init_actions.lua:627-634) e alguns callers de HARVEST passam
	-- argumentos extras depois do `act`. Sem o reencaminhamento, o wrapper do outro
	-- mod receiving nil no lugar desses argumentos.
	if OldHarvestfn == nil then
		return false
	end
	return OldHarvestfn(act, ...)
end
