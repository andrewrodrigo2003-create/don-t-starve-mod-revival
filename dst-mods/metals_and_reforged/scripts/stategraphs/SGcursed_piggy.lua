require("stategraphs/commonstates")

local events = {
	EventHandler("attacked", function(inst, data) 
		if data.stimuli and data.stimuli == "electric" and not inst.components.health:IsDead() then
			inst.sg:GoToState("hit", data.stimuli)
		elseif not inst.components.health:IsDead() and not inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("nointerrupt") then 
			inst.sg:GoToState("hit") 
		end 
	end),
	
	EventHandler("doattack", function(inst, data)
		if not inst.components.health:IsDead() and (inst.sg:HasStateTag("hit") or not inst.sg:HasStateTag("busy")) then
		    inst.sg:GoToState("attack", data.target)
		end
	end),

    CommonHandlers.OnStep(),
    CommonHandlers.OnLocomote(true, false),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnDeath(),
}

--------------------------------------------------------------------------

local function ShouldStopCurseOrRitual(inst)
    return inst.stopritualorcurse and not inst.components.combat:HasTarget()
end

--------------------------------------------------------------------------

local states = {
    State{
	    name = "idle",
		tags = { "idle" },
		
		onenter = function(inst)
				--inst.Physics:Stop()
				inst.AnimState:PlayAnimation("idle")
		end,
		
		events = {
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
	},
	
    State{
        name = "attack",
		tags = { "attack", "busy" },
        onenter = function(inst)
            inst.Physics:Stop()
			inst.components.combat:StartAttack()
			inst.SoundEmitter:PlaySound(inst.sounds.attack)
            inst.AnimState:PlayAnimation("atk")
        end,

		timeline = {
			TimeEvent(10 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/creatures/leif/swipe")
			end),
			TimeEvent(17 * FRAMES, function(inst)
			    inst.components.combat:DoAttack()
			end),
        },
		
		events = {
			EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
			end),
		},
    },
	
	State{
		name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst, cb)
            inst.Physics:Stop()
			inst.SoundEmitter:PlaySound(inst.sounds.hit)
            inst.AnimState:PlayAnimation("hit")
        end,

		events = {
			EventHandler("animover", function(inst)
				inst.sg:GoToState("idle")
			end),
		},
    },
	
	State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound(inst.sounds.death)
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst.components.lootdropper:DropLoot(inst:GetPosition())
        end,
    },
	
	State{
        name = "stopcurse",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound(inst.sounds.death)
            inst.AnimState:PlayAnimation("atk")
        end,
    },
}

CommonStates.AddRunStates(states, {
    runtimeline = {
        TimeEvent(1 * FRAMES, PlayFootstep),
		TimeEvent(12 * FRAMES, PlayFootstep),
    },
	
	endtimeline = {},
})

return StateGraph("cursed_piggy", states, events, "idle")