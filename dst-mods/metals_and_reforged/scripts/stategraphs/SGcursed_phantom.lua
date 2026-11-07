require("stategraphs/commonstates")

local actionhandlers ={
    ActionHandler(ACTIONS.GOHOME, "action"),
}

local events ={
    EventHandler("attacked", function(inst)
        if not (inst.sg:HasStateTag("attack") or inst.sg:HasStateTag("hit") or inst.sg:HasStateTag("noattack") or inst.components.health:IsDead()) then
            inst.sg:GoToState("hit")
        end
    end),
    EventHandler("death", function(inst) inst.sg:GoToState("death") end),
    EventHandler("doattack", function(inst, data)
        if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
            inst.sg:GoToState("attack", data.target)
        end
    end),

    CommonHandlers.OnLocomote(true, false),
}

local function FinishExtendedSound(inst, soundid)
    inst.SoundEmitter:KillSound("sound_"..tostring(soundid))
    inst.sg.mem.soundcache[soundid] = nil
    if inst.sg.statemem.readytoremove and next(inst.sg.mem.soundcache) == nil then
        inst:Remove()
    end
end

local function PlayExtendedSound(inst, soundname)
    if inst.sg.mem.soundcache == nil then
        inst.sg.mem.soundcache = {}
        inst.sg.mem.soundid = 0
    else
        inst.sg.mem.soundid = inst.sg.mem.soundid + 1
    end
    inst.sg.mem.soundcache[inst.sg.mem.soundid] = true
    inst.SoundEmitter:PlaySound(inst.sounds[soundname], "sound_"..tostring(inst.sg.mem.soundid))
    inst:DoTaskInTime(5, FinishExtendedSound, inst.sg.mem.soundid)
end

local function OnAnimOverRemoveAfterSounds(inst)
    if inst.sg.mem.soundcache == nil or next(inst.sg.mem.soundcache) == nil then
        inst:Remove()
    else
        inst:Hide()
        inst.sg.statemem.readytoremove = true
    end
end

local states = {
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.wantstodespawn then
                local t = GetTime()
                if t > inst.components.combat:GetLastAttackedTime() + 5 then
                    local target = inst.components.combat.target
                    if target == nil or
                        target.components.combat == nil or
                        not target.components.combat:IsRecentTarget(inst) or
                        t > (target.components.combat.laststartattacktime or 0) + 5 then
                        inst.sg:GoToState("disappear")
                        return
                    end
                end
            end

            inst.components.locomotor:StopMoving()
            if not inst.AnimState:IsCurrentAnimation("idle_loop") then
                inst.AnimState:PlayAnimation("idle_loop", true)
            end
        end,
    },

    State{
        name = "run_start",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("run_pre")
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("run")
                end
            end),
        },

        timeline = {
            TimeEvent(4*FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
            end),
        },
    },

    State{
        name = "run",
        tags = {"moving", "running", "canrotate"},

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            if not inst.AnimState:IsCurrentAnimation("run_loop") then
                inst.AnimState:PlayAnimation("run_loop", true)
            end
            inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
        end,

        timeline = {
            TimeEvent(7 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
            end),
            TimeEvent(15 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/maxwell/shadowmax_step")
            end),
        },

        ontimeout = function(inst)
            inst.sg:GoToState("run")
        end,
    },

    State{
        name = "run_stop",
        tags = {"canrotate", "idle"},

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("run_pst")
        end,

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "attack",
        tags = {"attack", "notalking", "abouttoattack", "busy"},

        onenter = function(inst)
            inst.sg.statemem.target = inst.components.combat.target
            inst.components.combat:StartAttack()
            inst.Physics:Stop()
			inst.AnimState:AddOverrideBuild("lavaarena_shadow_lunge")
			inst.AnimState:SetBank("lavaarena_shadow_lunge")
            inst.AnimState:PlayAnimation("lunge_loop")
            inst.AnimState:PushAnimation("lunge_pst")

            if inst.components.combat.target ~= nil and inst.components.combat.target:IsValid() then
                inst:FacePoint(inst.components.combat.target.Transform:GetWorldPosition())
            end
        end,

        timeline = {
            TimeEvent(8*FRAMES, function(inst)
			    inst.components.combat:DoAttack(inst.sg.statemem.target)
				inst.sg:RemoveStateTag("abouttoattack")
			end),
            TimeEvent(12*FRAMES, function(inst)
                inst.sg:RemoveStateTag("busy")
            end),
            TimeEvent(19*FRAMES, function(inst)
                inst.AnimState:SetBank("wilson")
                local max_tries = 4
                for k = 1, max_tries do
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local offset = 10
                    x = x + math.random(2 * offset) - offset
                    z = z + math.random(2 * offset) - offset
                    if TheWorld.Map:IsPassableAtPoint(x, y, z) then
                        inst.Physics:Teleport(x, y, z)
                        break
                    end
                end

                inst.sg:GoToState("appear")
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy", "hit" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("hit")
            fns.SafeErode(inst, 1)
        end,

        events = {
            EventHandler("animover", function(inst)
                local max_tries = 4
                for k = 1, max_tries do
                    local x, y, z = inst.Transform:GetWorldPosition()
                    local offset = 10
                    x = x + math.random(2 * offset) - offset
                    z = z + math.random(2 * offset) - offset
                    if TheWorld.Map:IsPassableAtPoint(x, y, z) then
                        inst.Physics:Teleport(x, y, z)
                        break
                    end
                end

                inst.sg:GoToState("appear")
            end),
        },
    },

    State{
        name = "taunt",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("emote_impatient")
            PlayExtendedSound(inst, "taunt")
        end,

        events = {
            EventHandler("animover", function(inst)
		    	inst.sg:GoToState("idle")
			end),
        },
    },

    State{
        name = "appear",
        tags = { "busy" },

        onenter = function(inst)
            inst.AnimState:PlayAnimation("jumpout", true)
            inst.Physics:Stop()
            PlayExtendedSound(inst, "appear")
            fns.ReverseErode(inst, 1)
        end,

        events = {
            EventHandler("animover", function(inst)
		    	inst.sg:GoToState("idle")
			end)
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            PlayExtendedSound(inst, "death")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
            inst:AddTag("NOCLICK")
            inst.persists = false
        end,

        events = {
            EventHandler("animover", OnAnimOverRemoveAfterSounds),
        },

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
        end
    },

    State{
        name = "disappear",
        tags = { "busy", "noattack" },

        onenter = function(inst)
            PlayExtendedSound(inst, "death")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            inst:AddTag("NOCLICK")
            inst.persists = false
        end,

        events = {
            EventHandler("animover", OnAnimOverRemoveAfterSounds),
        },

        onexit = function(inst)
            inst:RemoveTag("NOCLICK")
        end,
    },

    State{
        name = "action",
        onenter = function(inst, playanim)
            inst.Physics:Stop()
            inst:PerformBufferedAction()
        end,

        events = {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle") end),
        },
    },

    State{
        name = "teleport_to_sea",
        tags = { "busy", "noattack", "teleporting" },
        onenter = function(inst, playanim)

                local x,y,z = inst.Transform:GetWorldPosition()
                local fx = SpawnPrefab("shadow_teleport_out")
                fx.Transform:SetPosition(x,y,z)

            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("taunt", false)
            inst.AnimState:PushAnimation("disappear", false)
        end,

        timeline = {
            TimeEvent(40*FRAMES, function(inst)
                local x,y,z = inst.Transform:GetWorldPosition()
                print("TELEPORT OUT TERRORBEAK")
                local fx = SpawnPrefab("shadow_teleport_out")
                fx.Transform:SetPosition(x,y,z)
            end),
        },

        events = {
            EventHandler("animqueueover", function(inst)
                print("EXCHANGE TERROR BEAK")
                inst:ExchangeWithOceanTerror()
                inst:Remove()
            end),
        },
    },
}

return StateGraph("cursed_phantom", states, events, "appear", actionhandlers)
