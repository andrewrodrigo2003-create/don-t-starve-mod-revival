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
local MAMConfig = require("mam/config")

local function say_smelter_failure(doer, ptbr, english)
    if doer ~= nil and doer.components ~= nil and doer.components.talker ~= nil then
        doer.components.talker:Say(
            MAMConfig.get("mam_language", "ptbr") == "en" and english or ptbr
        )
    end
end
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
				say_smelter_failure(act.doer,
					"Recolha o resultado atual antes de iniciar outro lote.",
					"Collect the current result before starting another batch.")
				return false
			end

			local started = smelter:StartSmelting(act.doer)
			if not started then
				local plan = smelter:Forecast()
				local invalid = plan ~= nil and (plan.state == "invalid" or plan.phase == "invalid")
				say_smelter_failure(act.doer,
					invalid and "Essa combinação não pode ser fundida."
						or "A carga não pôde ser processada; confira os materiais.",
					invalid and "This combination cannot be smelted."
						or "The load could not be processed; check the materials.")
			end
			return started and true or false
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
local MAMConfig = require("mam/config")
local FindEntities = GLOBAL.TheSim.FindEntities
local SpawnPrefab = GLOBAL.SpawnPrefab

local function has_warworkbench(doer)
    if doer == nil or doer.Transform == nil then
        return false
    end
    local x, y, z = doer.Transform:GetWorldPosition()
    local entities = FindEntities(GLOBAL.TheSim, x, y, z, 8, { "prototyper" }, { "INLIMBO", "burnt" })
    return MAMDeconstruction.HasWarWorkbench(entities,
        GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim == true)
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

local function plan_output_slots(inventory, staged)
    local function scan(container, slots_table, count)
        local storage = { container = container, slots = {} }
        for index = 1, count do
            local item = slots_table[index]
            table.insert(storage.slots, {
                index = index,
                item = item,
                room = item ~= nil and item.components.stackable ~= nil
                    and math.max(0, item.components.stackable:RoomLeft()) or 0,
            })
        end
        return storage
    end

    local primary = scan(inventory, inventory.itemslots, inventory.maxslots)
    local container = inventory:GetOverflowContainer()
    local overflow = container ~= nil and scan(container, container.slots, container.numslots) or nil
    local placements = {}

    for _, output in ipairs(staged) do
        local stackable = output.components.stackable
        local remaining = stackable ~= nil and stackable:StackSize() or 1
        local maxsize = stackable ~= nil and math.max(1, stackable.maxsize or 1) or 1
        local order = { primary, overflow }
        if overflow ~= nil and overflow.container:ShouldPrioritizeContainer(output) then
            order = { overflow, primary }
        end

        for pass = 1, 2 do
            for _, storage in ipairs(order) do
                for _, slot in ipairs(storage.slots) do
                    local destination = storage.container
                    if remaining > 0 and destination:CanTakeItemInSlot(output, slot.index) then
                        local room = 0
                        if pass == 1 and slot.item ~= nil and stackable ~= nil
                            and destination.acceptsstacks
                            and slot.item.components.stackable ~= nil
                            and slot.item.components.stackable:CanStackWith(output) then
                            room = slot.room
                        elseif pass == 2 and slot.item == nil then
                            room = destination.acceptsstacks and maxsize or 1
                        end
                        if room > 0 then
                            local amount = math.min(remaining, room)
                            table.insert(placements, {
                                item = output,
                                count = amount,
                                container = destination,
                                slot = slot.index,
                            })
                            slot.item = slot.item or output
                            slot.room = room - amount
                            remaining = remaining - amount
                        end
                    end
                end
            end
        end
        if remaining > 0 then
            return nil
        end
    end

    return placements
end

local deconstruct_action = AddAction("MAM_DECONSTRUCT_METAL", "Dismantle", function(act)
    local doer = act.doer
    local item = act.invobject or act.target
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim
        or doer == nil or item == nil or not item:IsValid()
        or doer.components == nil or doer.components.inventory == nil
        or item.components == nil or item.components.inventoryitem == nil
        or item.components.inventoryitem.owner ~= doer
        or not has_warworkbench(doer) then
        return false
    end

    local inventory = doer.components.inventory
    -- Material-only policy: no live recipe or equipment durability can expand this allowlist.
    local plan = MAMDeconstruction.BuildPlan(item.prefab, doer.prefab, math.random)
    if plan == nil then
        return false
    end

    local staged = stage_output_items(plan)
    if staged == nil then
        return false
    end
    local placements = plan_output_slots(inventory, staged)
    if placements == nil then
        for _, output in ipairs(staged) do
            if output:IsValid() then output:Remove() end
        end
        if doer.components.talker ~= nil then
            doer.components.talker:Say(MAMConfig.get("mam_language", "ptbr") == "en"
                and "Make room for the recovered materials first."
                or "Libere espaço para os materiais recuperados.")
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

    for _, placement in ipairs(placements) do
        local output = placement.item
        if output.components.stackable ~= nil
            and output.components.stackable:StackSize() > placement.count then
            output = output.components.stackable:Get(placement.count)
        end
        -- Use the reserved slot so overflow priority cannot consume another output's space.
        local accepted = placement.container:GiveItem(output, placement.slot)
        if not accepted and output:IsValid() and output.components.inventoryitem.owner == nil then
            local x, y, z = doer.Transform:GetWorldPosition()
            output.Transform:SetPosition(x, y, z)
            output.components.inventoryitem:OnDropped(true)
        end
    end
    consumed:Remove()
    return true
end)
STRINGS.ACTIONS.MAM_DECONSTRUCT_METAL = MAMConfig.get("mam_language", "ptbr") == "en"
    and "Dismantle" or "Desmontar"
deconstruct_action.rmb = true
deconstruct_action.mount_valid = true

AddComponentAction("INVENTORY", "inventoryitem", function(inst, doer, actions, right)
    local supported_material = inst ~= nil and MAMDeconstruction.IsSupported(inst.prefab)
    if right and inst ~= nil and inst:IsValid()
        and supported_material
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
    if show and inst ~= nil and inst:IsValid()
        and GLOBAL.TheFrontEnd ~= nil and not inst._mam_metallurgy_book_open then
        inst._mam_metallurgy_book_open = true
        GLOBAL.TheFrontEnd:PushScreen(require("screens/metallurgybookscreen")(inst))
    end
end
