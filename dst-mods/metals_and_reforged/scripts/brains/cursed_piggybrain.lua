require "behaviours/wander"
require "behaviours/chaseandattack"
require "behaviours/follow"
require "behaviours/chattynode"

local MIN_FOLLOW = 5
local MED_FOLLOW = 15
local MAX_FOLLOW = 30

local HARASS_MIN = 0
local HARASS_MED = 4
local HARASS_MAX = 5

local ShadowCreatureBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
    self.mytarget = nil
end)

function ShadowCreatureBrain:SetTarget(target)
    if target ~= nil then
        if not target:IsValid() then
            target = nil
        elseif self.listenerfunc == nil then
            self.listenerfunc = function() self.mytarget = nil end
        end
    end
    if target ~= self.mytarget then
        if self.mytarget ~= nil then
            self.inst:RemoveEventCallback("onremove", self.listenerfunc, self.mytarget)
        end
        if target ~= nil then
            self.inst:ListenForEvent("onremove", self.listenerfunc, target)
        end
        self.mytarget = target
    end
end

function ShadowCreatureBrain:OnStop()
    self:SetTarget(nil)
end

local function ShouldAttack(self)
    self._harasstarget = nil
    return true
end

local function ShouldHarass(self)
    return self._harasstarget ~= nil
        and self._harasstarget:IsValid()
        and (self.inst.components.combat.nextbattlecrytime == nil or
            self.inst.components.combat.nextbattlecrytime < GetTime())
end

local function ShouldChaseAndHarass(self)
    return self.inst.components.locomotor.walkspeed < 5
        or not self.inst:IsNear(self._harasstarget, HARASS_MED)
end

local function GetHarassWanderDir(self)
    return (self._harasstarget:GetAngleToPoint(self.inst.Transform:GetWorldPosition()) - 60 + math.random() * 120) * DEGREES
end

function ShadowCreatureBrain:OnStart()
    self:SetTarget(self.inst.spawnedforplayer)

    local root = PriorityNode(
    {
        ChattyNode(self.inst, "CURSED_PIGGY_TALK_FIGHT", WhileNode(function() return ShouldAttack(self) end, "Attack", ChaseAndAttack(self.inst, 100))),
        WhileNode(function() return ShouldHarass(self) end, "Harass",
            PriorityNode({
                WhileNode(function() return ShouldChaseAndHarass(self) end, "ChaseAndHarass",
                    Follow(self.inst, function() return self._harasstarget end, HARASS_MIN, HARASS_MED, HARASS_MAX)),
                ActionNode(function()
                    self.inst.components.combat:BattleCry()
                    if self.inst.sg.currentstate.name == "taunt" then
                        self.inst:ForceFacePoint(self._harasstarget.Transform:GetWorldPosition())
                    end
                end),
            }, .25)),
        WhileNode(function() return self._harasstarget ~= nil and self._harasstarget:IsValid() end, "LoiterAndHarass",
            Wander(self.inst, function() return self._harasstarget:GetPosition() end, 20, { minwaittime = 0, randwaittime = .3 }, function() return GetHarassWanderDir(self) end)),
        Follow(self.inst, function() return self.mytarget end, MIN_FOLLOW, MED_FOLLOW, MAX_FOLLOW),
        Wander(self.inst, function() return self.mytarget ~= nil and self.mytarget:GetPosition() or nil end, 20),
    }, .25)

    self.bt = BT(self.inst, root)
end

return ShadowCreatureBrain