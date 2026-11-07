GLOBAL.setmetatable(GLOBAL.getfenv(1), {__index = function(self, index)
	return GLOBAL.rawget(GLOBAL, index)
end})

TUNING.PITHPIKEOLD_PERISHTIME = 480 * 10--20 

if not TheNet:GetIsMasterSimulation() then return end

AddPrefabPostInit("pithpikeold", function(inst)
	inst:AddComponent"fueled"
	inst.components.fueled.fueltype = FUELTYPE.USAGE
	inst.components.fueled:SetDepletedFn(inst.Remove)
	inst.components.fueled:InitializeFuelLevel(TUNING.PITHPIKEOLD_PERISHTIME)
	
	inst._onlocomote = function(owner)
        if not inst.components.fueled then 
        	return 
        elseif not owner.components.locomotor then 
            inst.components.fueled:StopConsuming()
        elseif owner.components.locomotor.wantstomoveforward then
            inst.components.fueled:StartConsuming()
        else
            inst.components.fueled:StopConsuming()
        end
	end
	
	for event, func in pairs{
		equipped = function(inst, data)
			if not data or not data.owner then return end 
			inst:ListenForEvent("locomote", inst._onlocomote, data.owner)
		end, 
		
		unequipped = function(inst, data)
			if not data or not data.owner then return end 
			inst:RemoveEventCallback("locomote", inst._onlocomote, data.owner)
		end, 
	} do inst:ListenForEvent(event, func) end 
end)

