GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

AddPrefabPostInit("bernie_big", function(inst)
    if not TheWorld.ismastersim then
        return inst
    end
    inst.attacktime = 0
            local _getAttacked = inst.components.combat.GetAttacked
                   inst.components.combat.GetAttacked = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
                              local currenthealth = inst.components.health.currenthealth
                                     if inst.attacktime > 0 then
                                                damage = 0
                                                inst.attacktime = inst.attacktime - 1

                                        elseif currenthealth < 2100 then 
                                                     damage = damage*0.3
                                               else
                                            damage = damage*0.45  
                                     end 

                     return _getAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...) 
      end

            local _doAreaAttack = inst.components.combat.DoAreaAttack
                   inst.components.combat.DoAreaAttack = function(self, target, range, weapon, validfn, stimuli, excludetags, onlyontarget, ...)
        local function get_area_damage()
            if inst.components.combat.defaultdamage == 72.8 then
                return 70.2
            elseif inst.components.combat.defaultdamage == 85 then
                return 82
            end
            return 54
        end

        if target == nil then
            return 0
        end

        if select("#", ...) > 0 then
            return _doAreaAttack(self, target, range, weapon, validfn, stimuli, excludetags, onlyontarget, ...)
        end

        if onlyontarget then
            local leaders = target.components.follower and target.components.follower.leader
            if self:IsValidTarget(target) and
                (validfn == nil or validfn(target, self.inst)) and
                not (leaders and leaders:HasTag("player")) and
                target.components.combat ~= nil then
                self.inst:PushEvent("onareaattackother", { target = target, weapon = weapon, stimuli = stimuli })
                target.components.combat:GetAttacked(self.inst, get_area_damage(), weapon, stimuli)
                return 1
            end
            return 0
        end

        local hitcount = 0
        local bernie_exclude_tags = { "INLIMBO", "player", "companion", "wall" }
        for _, tag in ipairs(excludetags or {}) do
            table.insert(bernie_exclude_tags, tag)
        end
        if target.Transform == nil then
            return 0
        end
        local x, y, z = target.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, range, { "_combat" }, bernie_exclude_tags)
        for _, ent in ipairs(ents) do
            local leaders = ent.components.follower and ent.components.follower.leader
            if ent ~= target and ent ~= self.inst and self:IsValidTarget(ent) and
                (validfn == nil or validfn(ent, self.inst)) and
                not (leaders and leaders:HasTag("player")) and ent.components.combat ~= nil then
                self.inst:PushEvent("onareaattackother", { target = ent, weapon = weapon, stimuli = stimuli })
                ent.components.combat:GetAttacked(self.inst, get_area_damage(), weapon, stimuli)
                hitcount = hitcount + 1
            end
        end

        return hitcount
    end = 4
    inst.components.combat:SetDefaultDamage(56)
    inst.components.combat:SetAreaDamage(4)
    inst.components.health:SetMaxHealth(3200)

   -- inst:ListenForEvent("onhitother", OnHitOther)
end)

local function GoBig(inst)
    local skin_name = nil
    if inst:GetSkinName() ~= nil then
        skin_name = string.gsub(inst:GetSkinName(), "_active", "_big")
    end
    
    local big = SpawnPrefab("bernie_big", skin_name, inst.skin_id, nil)
    if big ~= nil then
        --Rescale health %
        if inst.attacktime > 0 then
                     big.attacktime = inst.attacktime
        end
        big.components.health:SetPercent(inst.components.health:GetPercent())
        big.Transform:SetPosition(inst.Transform:GetWorldPosition())
        big.Transform:SetRotation(inst.Transform:GetRotation())
        inst:Remove()
        return big
    end
end

AddPrefabPostInit("bernie_active", function(inst) --._leader

    if not TheWorld.ismastersim then
        return inst
    end

    inst.attacktime = 0
    inst.GoBig = GoBig

    inst.components.health:SetMaxHealth(1500)
                local _getAttacked = inst.components.combat.GetAttacked
                   inst.components.combat.GetAttacked = function(self, attacker, damage, weapon, stimuli, spdamage, ...) 
                              local currenthealth = inst.components.health.currenthealth
                                      if inst.attacktime > 0 then
                                                damage = 0
                                                inst.attacktime = inst.attacktime - 1
                                        elseif  currenthealth < 800 then 
                                                     damage = damage*0.75
   
                                     end              
                     return _getAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...) 
      end
end)

AddPrefabPostInit("willow", function(inst) --._leader

    if not TheWorld.ismastersim then
        return inst
    end

                local _getAttacked = inst.components.combat.GetAttacked
                   inst.components.combat.GetAttacked = function(self, attacker, damage, weapon, stimuli, spdamage, ...)
                                          local x, y, z = inst.Transform:GetWorldPosition()
                                          local ents = TheSim:FindEntities(x, y, z, 30)
                                              for i, ent in ipairs(ents) do
                                                       if ent.prefab == "bernie_active" and ent.components.health.currenthealth < 800 then
                                                                damage = damage*0.75
                                                          end       
                                               end             
                     return _getAttacked(self, attacker, damage, weapon, stimuli, spdamage, ...) 
      end
end)      

local function OnSewing(inst)
    if not TheWorld.ismastersim then
        return inst
    end

            local _doSewing = inst.components.sewing.DoSewing
                   inst.components.sewing.DoSewing = function(self, target, doer)

                                          if target.prefab == "bernie_inactive" and math.random() <= 0.3 then
                                                          doer.components.talker:Say("不，我以为能修好你的..")
                                                              local fx = SpawnPrefab("collapse_big")
                                                              fx.Transform:SetScale(0.3, 0.3, 0.3)
                                                              fx.Transform:SetPosition(target.Transform:GetWorldPosition())

                                                            if self.inst.components.finiteuses then
                                                                          self.inst.components.finiteuses:Use(1)
                                                                 elseif self.inst.components.stackable then
                                                                           self.inst.components.stackable:Get(1):Remove()
                                                          end                  

                                            return true
    
                                               elseif math.random() <= 0.1 and target.attacktime == 0 then
                                                target.attacktime = target.attacktime+3
                                                target.Transform:SetScale(2, 2, 2)
                                                     local fx = SpawnPrefab("sand_puff")
                                                           fx.Transform:SetScale(1.8, 1.8, 1.8)
                                                           fx.Transform:SetPosition(target.Transform:GetWorldPosition())
                                     end 

                     return _doSewing(self, target, doer) 
      end
end

AddPrefabPostInit("sewing_tape", OnSewing) 
AddPrefabPostInit("sewing_kit", OnSewing)