local a =
    Class(
    function(self, b)
        self.inst = b
        self.spell_type = nil
        self.aoe_cast = nil
    end
)
function a:SetAOESpell(c)
    self.aoe_cast = c
end
function a:CanCast(d, e)
    local f, g, h = e:Get()
    return self.inst.components.rechargeable ~= nil and self.inst.components.rechargeable:IsCharged() and
        (self.inst.components.aoetargeting ~= nil and self.inst.components.aoetargeting.alwaysvalid or
            TheWorld.Map:IsPassableAtPoint(f, g, h) and not TheWorld.Map:IsGroundTargetBlocked(e))
end
function a:CastSpell(d, e)
    if self.inst.components.reticule_spawner ~= nil then
        self.inst.components.reticule_spawner:Spawn(e)
    end
    if self.aoe_cast ~= nil then
        self.aoe_cast(self.inst, d, e)
    end
    self.inst:PushEvent("aoe_casted", {caster = d, pos = e})
end
function a:SetSpellType(i)
    self.spell_type = i
end
function a:OnSpellCast(d, j, k)
    self.casting = false
    d:PushEvent("spell_complete", {weapon = self.inst, spell_type = self.spell_type, targets = j, projectiles = k})
end
return a
