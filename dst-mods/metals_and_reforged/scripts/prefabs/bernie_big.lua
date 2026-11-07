local brain = require("brains/berniebigbrain")

local assets =
{
    Asset("ANIM", "anim/bernie_big.zip"),
    Asset("ANIM", "anim/bernie_build.zip"),
}

local prefabs =
{
    "bernie_inactive",
}

local TARGET_DIST = 12
local TAUNT_DIST = 16
local TAUNT_PERIOD = 2

local function goinactive(inst)
    local skin_name = nil
    if inst:GetSkinName() ~= nil then
        skin_name = string.gsub(inst:GetSkinName(), "_big", "")
    end
    local inactive = SpawnPrefab("bernie_inactive", skin_name, inst.skin_id, nil)
    if inactive ~= nil then
        --Transform health % into fuel.
        inactive.components.fueled:SetPercent(inst.components.health:GetPercent())
        inactive.Transform:SetPosition(inst.Transform:GetWorldPosition())
        inactive.Transform:SetRotation(inst.Transform:GetRotation())
        inactive.components.timer:StartTimer("transform_cd", TUNING.BERNIE_BIG_COOLDOWN)
        inst:Remove()
        return inactive
    end
end

local function IsTauntable(inst, target)
    local leader = inst.brain and inst.brain._leader
    return not (target.components.health ~= nil and target.components.health:IsDead())
        and target.components.combat ~= nil
        and not target.components.combat:TargetIs(inst)
        and target.components.combat:CanTarget(inst)
        and ((target:HasTag("shadowcreature") and leader and leader.components.sanity and leader.components.sanity:IsCrazy()) or
                (   target.components.combat:HasTarget() and
                    (   target.components.combat.target:HasTag("player") or
                        (target.components.combat.target:HasTag("companion") and target.components.combat.target.prefab ~= inst.prefab)
                    )
                )
            )
end

local function IsTargetable(inst, target)
    local leader = inst.brain and inst.brain._leader
    return not (target.components.health ~= nil and target.components.health:IsDead()) 
        and target.components.combat ~= nil
        and target.components.combat:CanTarget(inst)
        and (  target.components.combat:TargetIs(inst) or
                (target:HasTag("shadowcreature") and leader and leader.components.sanity and leader.components.sanity:IsCrazy()) or
                (   target.components.combat:HasTarget() and
                    (   target.components.combat.target:HasTag("player") or
                        target.components.combat.target:HasTag("companion")
                    )
                )
            )
end

local function TauntCreatures(inst)
    if not inst.components.health:IsDead() then
        local x, y, z = inst.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, y, z, TAUNT_DIST, { "_combat", "locomotor" }, { "INLIMBO", "player", "companion", "epic", "notaunt" })) do
            if IsTauntable(inst, v) then
                v.components.combat:SetTarget(inst)
            end
        end
    end
end

local function OnLoad(inst)
    inst._taunttask:Cancel()
    inst._taunttask = inst:DoPeriodicTask(TAUNT_PERIOD, TauntCreatures, math.random() * TAUNT_PERIOD)
    inst.sg:GoToState("idle")
end

local function RetargetFn(inst)
    if inst.components.combat:HasTarget() then
        return
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    for i, v in ipairs(TheSim:FindEntities(x, y, z, TARGET_DIST, { "_combat" }, { "INLIMBO", "player", "companion" }, { "locomotor", "epic" })) do
        if IsTargetable(inst, v) then
            return v
        end
    end
end

local function KeepTargetFn(inst, target)
    return inst.components.combat:CanTarget(target) and inst:IsNear(target, TARGET_DIST)
end

local function OnHitOther(inst, data)
    if data.target ~= nil and data.target.components.health and inst.buff_sewing_kit1 then  

                    if data.target.task then
                                data.target.task:Cancel()
                                data.target.task = nil 
                 end

             data.target.components.health:StartRegen(math.random(-2, -1), 1)

             data.target.task = data.target:DoTaskInTime(5, function()
                     data.target.components.health:StopRegen()
                     print("="..data.target.prefab) 
                           if data.target.task then
                                data.target.task:Cancel()
                                data.target.task = nil 
                        end   
             end)      
    end
end

local function OnAttacked(inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if attacker ~= nil and not PreventTargetingOnAttacked(inst, attacker, TheNet:GetPVPEnabled() and "bernieowner" or "player") then
        local target = inst.components.combat.target
        if not (target ~= nil and target:IsValid() and inst:IsNear(target, TUNING.BERNIE_BIG_ATTACK_RANGE + target:GetPhysicsRadius(0))) then
            inst.components.combat:SetTarget(attacker)
        end
    end
end

local function OnSleepTask(inst)
    inst._sleeptask = nil
    inst:GoInactive()
end

local function OnEntitySleep(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask = inst:DoTaskInTime(.5, OnSleepTask)
    end
end

local function OnEntityWake(inst)
    if inst._sleeptask ~= nil then
        inst._sleeptask:Cancel()
        inst._sleeptask = nil
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    MakeCharacterPhysics(inst, 500, .65)
    inst.DynamicShadow:SetSize(2.75, 1.3)

    inst.Transform:SetScale(.7, .7, .7)
    inst.Transform:SetFourFaced()

    inst.AnimState:SetBank("bernie_big")
    inst.AnimState:SetBuild("bernie_build")
    inst.AnimState:PlayAnimation("idle_loop", true)


    --inst.AnimState:SetScale(0.5, 0.5, 0.5)


    inst:AddTag("largecreature")
    inst:AddTag("companion")
    inst:AddTag("soulless")
    inst:AddTag("crazy")
    inst:AddTag("needssewing")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.buff_sewing_kit1 = false
    inst.buff_sewing_kit2 = false
    inst.buff_sewing_kit3 = false
    inst.buff_sewing_kit4 = false
    inst.buff_sewing_kit5 = false

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.BERNIE_BIG_HEALTH)
    inst.components.health.nofadeout = true

    inst:AddComponent("inspectable")

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = TUNING.BERNIE_BIG_WALK_SPEED*1.5
    inst.components.locomotor.runspeed = TUNING.BERNIE_BIG_RUN_SPEED*1.5

    -- Enable boat hopping
    inst.components.locomotor:SetAllowPlatformHopping(true)
    inst:AddComponent("embarker")

    inst:AddComponent("fueled")
    inst.components.fueled.fueltype = FUELTYPE.USAGE
    inst.components.fueled.rate = 0
    inst.components.fueled.maxfuel = 100
    inst.components.fueled.currentfuel = 99

    local _doDodelta = inst.components.fueled.DoDelta
                   inst.components.fueled.DoDelta = function(self, amount, doer) --damage默认为攻击者的攻击力    
                                 amount = 0
                     return _doDodelta(self, amount, doer) 
    end

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", function(inst, data)
         if data.name == "Buff_sewing_kit1" then 
                inst.buff_sewing_kit1 = false
        end
         if data.name == "Buff_sewing_kit2" then 
                inst.buff_sewing_kit2 = false
                inst.components.health:StopRegen()
        end 
         if data.name == "Buff_sewing_kit3" then 
                inst.buff_sewing_kit3 = false
        end 
         if data.name == "Buff_sewing_kit4" then 
                inst.buff_sewing_kit4 = false
                    if inst.components.combat then
                         inst.components.combat:SetDefaultDamage(56)
                end          
        end
         if data.name == "Buff_sewing_kit5_1" then 
                    if inst.components.health then
                           inst.components.health:StopRegen()
                 end          
        end
         if data.name == "Buff_sewing_kit5_2" then 
                inst.buff_sewing_kit5 = false
        end 
    end)

    inst:DoTaskInTime(0, function(inst)
                 local Buff_sewing_kit1_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit1") or 0) or nil
                 local Buff_sewing_kit2_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit2") or 0) or nil
                 local Buff_sewing_kit3_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit3") or 0) or nil
                 local Buff_sewing_kit4_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit4") or 0) or nil
                 local Buff_sewing_kit5_1_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit5_1") or 0) or nil 
                 local Buff_sewing_kit5_2_Time = inst.components.timer ~= nil and (inst.components.timer:GetTimeLeft("Buff_sewing_kit5_2") or 0) or nil 

                       if Buff_sewing_kit1_Time and Buff_sewing_kit1_Time > 0 then
                             inst.buff_sewing_kit1 = true
                   end

                       if Buff_sewing_kit2_Time ~= nil and Buff_sewing_kit2_Time > 0 then
                             inst.buff_sewing_kit2 = true
                                  if inst.components.health then
                                         inst.components.health:StartRegen(math.random(10, 15), 1)
                            end          
                   end

                       if Buff_sewing_kit3_Time ~= nil and Buff_sewing_kit3_Time > 0 then
                             inst.buff_sewing_kit3 = true
                   end

                       if Buff_sewing_kit4_Time ~= nil and Buff_sewing_kit4_Time > 0 then
                                inst.buff_sewing_kit4 = true  
                                    if inst.components.combat then
                                          inst.components.combat:SetDefaultDamage(85)
                                end 
                   end

                       if Buff_sewing_kit5_1_Time ~= nil and Buff_sewing_kit5_1_Time > 0 then
                             inst.buff_sewing_kit5 = true
                                if inst.components.health then
                                         inst.components.health:StartRegen(20, 1)
                            end  
                   end 

                       if Buff_sewing_kit5_2_Time ~= nil and Buff_sewing_kit5_2_Time > 0 then
                             inst.buff_sewing_kit5 = true
                   end

       end)  

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(TUNING.BERNIE_BIG_DAMAGE)
    inst.components.combat:SetAttackPeriod(TUNING.BERNIE_BIG_ATTACK_PERIOD)
    inst.components.combat:SetRange(TUNING.BERNIE_BIG_ATTACK_RANGE, TUNING.BERNIE_BIG_HIT_RANGE)
    inst.components.combat:SetRetargetFunction(1, RetargetFn)
    inst.components.combat:SetKeepTargetFunction(KeepTargetFn)
    inst.components.combat.battlecryinterval = 16
    inst.components.combat.hiteffectsymbol = "body"

    inst:AddComponent("timer")

    inst:AddComponent("hauntable")
    inst.components.hauntable:SetHauntValue(TUNING.HAUNT_TINY)

    inst.hit_recovery = TUNING.BERNIE_BIG_HIT_RECOVERY

    inst:SetStateGraph("SGberniebig")
    inst:SetBrain(brain)

    inst._taunttask = inst:DoPeriodicTask(TAUNT_PERIOD, TauntCreatures, 0)
    inst.OnLoad = OnLoad
    inst.GoInactive = goinactive
    inst.OnEntitySleep = OnEntitySleep
    inst.OnEntityWake = OnEntityWake

    inst:ListenForEvent("onhitother", OnHitOther)
    inst:ListenForEvent("attacked", OnAttacked)

    return inst
end

return Prefab("bernie_big", fn, assets, prefabs)
