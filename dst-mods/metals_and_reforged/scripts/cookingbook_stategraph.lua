local State = GLOBAL.State
local FRAMES = GLOBAL.FRAMES
local EventHandler = GLOBAL.EventHandler
local EQUIPSLOTS = GLOBAL.EQUIPSLOTS
local TimeEvent = GLOBAL.TimeEvent
local ActionHandler = GLOBAL.ActionHandler
local ACTIONS = GLOBAL.ACTIONS
local TheNet = GLOBAL.TheNet
local SpawnPrefab = GLOBAL.SpawnPrefab
local PlayFootstep = GLOBAL.PlayFootstep
local Vector3 = GLOBAL.Vector3
local STRINGS = GLOBAL.STRINGS


local cookingbook = State{
	name = "cookingbook_idle",
	tags = { "idle", "cookingbook_idle" },

	onenter = function(inst)
		inst.components.locomotor:Stop()
		
		local INV = inst.replica.inventory ~= nil and inst.replica.inventory or inst.components.inventory ~= nil and inst.components.inventory
		local _cookingbook = INV and INV:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS) and INV:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS):HasTag("cookingbook") and INV:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS)
		local cookingbook_build = _cookingbook and "cookbook"
		inst.AnimState:OverrideSymbol("book_cook", cookingbook_build, "book_cook")
		
		if inst.sg.laststate == nil then
			inst.AnimState:PlayAnimation("reading_loop", true)
		else
			inst.SoundEmitter:PlaySound("dontstarve/wilson/backpack_close")
			inst.AnimState:PlayAnimation("action_uniqueitem_pre")
            inst.AnimState:PushAnimation("reading_in", false)
            inst.AnimState:PushAnimation("reading_loop", true)
		end
	end,

	events =
	{
		EventHandler("unequip", function(inst)
			inst.sg:GoToState("idle")
		end),
		
	},

	onexit = function(inst)
	end,
}

local function SGCookingServer_PostInit(sg)
    sg.states["cookingbook_idle"] = cookingbook
end

local function SGCookingClient_PostInit(sg)
    sg.states["cookingbook_idle"] = cookingbook
end

AddStategraphState("SGwilson", cookingbook)
AddStategraphPostInit("wilson", SGCookingServer_PostInit)

AddStategraphState("SGwilson_client", cookingbook)
AddStategraphPostInit("wilson_client", SGCookingClient_PostInit)