local a =
    Class(
    function(self, b)
        self.inst = b
        self.onparrystart = nil
        self.duration = 2
        self.max_angle = 70
        b:AddTag("parryweapon")
    end
)
function a:SetOnParryStartFn(c)
    self.onparrystart = c
end
function a:OnPreParry(d)
    if d.sg then
        d.sg:PushEvent("start_parry")
    end
    if self.onparrystart then
        self.onparrystart(self.inst, d)
    end
end
function a:TryParry(d, e, f, g, h)
    if d.sg then
        d.sg:PushEvent("try_parry")
    end
    if self.ontryparry then
        return self.ontryparry(d, e, f, g, h)
    end
    local i = e or g
    local j = d.Transform:GetRotation() - d:GetAngleToPoint(i.Transform:GetWorldPosition())
    local k = math.abs(j + (j > 180 and -360 or j < -180 and 360 or 0))
    local l =
        i.components.weapon and i.components.weapon.damagetype or i.components.combat and i.components.combat.damagetype
    return k <= self.max_angle and l == DAMAGETYPES.PHYSICAL
end
return a
