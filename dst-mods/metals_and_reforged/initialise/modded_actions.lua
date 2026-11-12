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

-- Material deconstruction is an inventory action available only beside the
-- existing War Bench. The server validates the station, input ownership and
-- complete output capacity before consuming a single item.
local MAMDeconstruction = require("mam/deconstruction")
local FindEntities = GLOBAL.TheSim.FindEntities
local SpawnPrefab = GLOBAL.SpawnPrefab

local function has_warworkbench(doer)
    if doer == nil or doer.Transform == nil then
        return false
    end
    local x, y, z = doer.Transform:GetWorldPosition()
    local entities = FindEntities(GLOBAL.TheSim, x, y, z, 8, { "prototyper" }, { "INLIMBO", "burnt" })
    for _, entity in ipairs(entities) do
        if entity.prefab == "warworkbench"
            and entity.components ~= nil
            and entity.components.prototyper ~= nil
            and entity:GetDistanceSqToInst(doer) <= 64 then
            return true
        end
    end
    return false
end

local function stage_output_items(plan)
    local staged = {}
    for _, entry in ipairs(plan) do
        local remaining = entry.count
        while remaining > 0 do
            local item = SpawnPrefab(entry.prefab)
            if item == nil then
                for _, previous in ipairs(staged) do
                    if previous:IsValid() then previous:Remove() end
                end
                return nil
            end
            local amount = 1
            if item.components ~= nil and item.components.stackable ~= nil then
                local maxsize = math.max(1, item.components.stackable.maxsize or 1)
                amount = math.min(remaining, maxsize)
                if amount > 1 then
                    item.components.stackable:SetStackSize(amount)
                end
            end
            table.insert(staged, item)
            remaining = remaining - amount
        end
    end
    return staged
end

local function can_fit_staged_outputs(inventory, staged)
    local slots = {}
    local free_slots = 0
    for index = 1, inventory.maxslots do
        local item = inventory.itemslots[index]
        if item == nil then
            free_slots = free_slots + 1
        else
            table.insert(slots, item)
        end
    end
    local overflow = inventory:GetOverflowContainer()
    if overflow ~= nil then
        for index = 1, overflow.numslots do
            local item = overflow.slots[index]
            if item == nil then
                free_slots = free_slots + 1
            else
                table.insert(slots, item)
            end
        end
    end

    for _, output in ipairs(staged) do
        local remaining = output.components.stackable ~= nil
            and output.components.stackable:StackSize() or 1
        local maxsize = output.components.stackable ~= nil
            and math.max(1, output.components.stackable.maxsize or 1) or 1

        for _, existing in ipairs(slots) do
            if remaining > 0 and existing.components ~= nil
                and existing.components.stackable ~= nil
                and output.components.stackable ~= nil
                and existing.components.stackable:CanStackWith(output) then
                local room = existing.components.stackable:RoomLeft()
                local used = math.min(remaining, room)
                remaining = remaining - used
            end
        end

        local needed = math.ceil(remaining / maxsize)
        free_slots = free_slots - needed
        if free_slots < 0 then
            return false
        end
        -- Reserve virtual slots so later outputs cannot reuse the same free slot.
        for _ = 1, needed do
            table.insert(slots, output)
        end
    end
    return true
end

local deconstruct_action = AddAction("MAM_DECONSTRUCT_METAL", "Dismantle", function(act)
    local doer = act.doer
    local item = act.invobject or act.target
    if doer == nil or item == nil or not item:IsValid()
        or doer.components == nil or doer.components.inventory == nil
        or item.components == nil or item.components.inventoryitem == nil
        or item.components.inventoryitem.owner ~= doer
        or not has_warworkbench(doer) then
        return false
    end

    local inventory = doer.components.inventory
    local recipe = GLOBAL.AllRecipes ~= nil and GLOBAL.AllRecipes[item.prefab] or nil
    if recipe ~= nil and recipe.no_deconstruction then
        return false
    end

    local durability = 1
    local finiteuses = item.components.finiteuses
    local armor = item.components.armor
    local fueled = item.components.fueled
    local durability_component = finiteuses or armor or fueled
    if durability_component ~= nil and type(durability_component.GetPercent) == "function" then
        local ok, percent = pcall(durability_component.GetPercent, durability_component)
        if ok and type(percent) == "number" then
            durability = math.max(0, math.min(1, percent))
        end
    end

    local plan = MAMDeconstruction.BuildPlan(item.prefab, doer.prefab,
        math.random, recipe, durability)
    if plan == nil or #plan == 0 then
        return false
    end

    local staged = stage_output_items(plan)
    if staged == nil then
        return false
    end
    if not can_fit_staged_outputs(inventory, staged) then
        for _, output in ipairs(staged) do
            if output:IsValid() then output:Remove() end
        end
        if doer.components.talker ~= nil then
            doer.components.talker:Say("Make room for the recovered materials first.")
        end
        return false
    end

    -- Remove exactly one input unit. Stackable:Get through RemoveItem(false)
    -- preserves the rest of the stack in its original slot.
    local consumed = inventory:RemoveItem(item, false)
    if consumed == nil then
        for _, output in ipairs(staged) do
            if output:IsValid() then output:Remove() end
        end
        return false
    end

    for _, output in ipairs(staged) do
        local accepted = inventory:GiveItem(output)
        if not accepted and output:IsValid() then
            -- The preflight should make this unreachable; preserve materials
            -- on the ground rather than deleting an output after input commit.
            local x, y, z = doer.Transform:GetWorldPosition()
            output.Transform:SetPosition(x, y, z)
            output.components.inventoryitem:OnDropped(true)
        end
    end
    consumed:Remove()
    return true
end)
deconstruct_action.rmb = true
deconstruct_action.mount_valid = true

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions, right)
    if right and inst ~= nil and inst:IsValid()
        and MAMDeconstruction.IsSupported(inst.prefab)
        and has_warworkbench(doer) then
        table.insert(actions, ACTIONS.MAM_DECONSTRUCT_METAL)
    end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.MAM_DECONSTRUCT_METAL, "doshortaction"))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.MAM_DECONSTRUCT_METAL, "doshortaction"))

-- Read-only metallurgy guide popup. The server sends the popup event; the
-- actual screen is created only on the local client.
local MAM_METALLURGY_BOOK_POPUP = AddPopup("MAM_METALLURGY_BOOK")
MAM_METALLURGY_BOOK_POPUP.fn = function(inst, show)
    if show and GLOBAL.TheFrontEnd ~= nil and not inst._mam_metallurgy_book_open then
        inst._mam_metallurgy_book_open = true
        GLOBAL.TheFrontEnd:PushScreen(require("screens/metallurgybookscreen")(inst))
    end
end
