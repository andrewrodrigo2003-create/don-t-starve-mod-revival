GLOBAL.setmetatable(GLOBAL.getfenv(1), {__index = function(self, index)
	return GLOBAL.rawget(GLOBAL, index)
end})

if not TheNet:GetIsMasterSimulation() then return end

AddPlayerPostInit(function(inst)
	inst:ListenForEvent("newstate", function(inst)
		local is_idle = inst.sg and inst.sg.currentstate.name == "idle"
		local holds_cookingbook = inst.components.inventory and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS):HasTag("cookingbook")
		local not_riding = not inst.components.rider or inst.components.rider and not inst.components.rider:IsRiding()
		if is_idle and holds_cookingbook and not_riding then
			inst.sg:GoToState("cookingbook_idle")
		end
	end)
end)