-- Static regression contract for the legacy Forge weapon component hooks.
-- Run from the repository root with Lua 5.1.

local path = "dst-mods/metals_and_reforged/scripts/mod_main.lua"
local file, err = io.open(path, "r")
assert(file ~= nil, "Could not open " .. path .. ": " .. tostring(err))
local source = file:read("*a")
file:close()

local required = {
    "local old_get_attack_range = self.GetAttackRange",
    "local old_get_hit_range = self.GetHitRange",
    "local old_calc_damage = self.CalcDamage",
    "local old_do_attack = self.DoAttack",
    "local old_get_attacked = self.GetAttacked",
    "local old_can_ranged_attack = self.CanRangedAttack",
    "local old_attack_range = self.AttackRange",
    "return self.altcondition == nil or self.altcondition(self.inst)",
}

for _, fragment in ipairs(required) do
    assert(source:find(fragment, 1, true) ~= nil,
        "Missing compatibility contract: " .. fragment)
end

local forbidden = {
    "_oldGetAttackRange = self.GetAttackRange",
    "_oldGetHitRange = self.GetHitRange",
    "_oldCalcDamage = self.CalcDamage",
    "_oldDoAttack = self.DoAttack",
    "_oldGetAttacked = self.GetAttacked",
    "_oldCanRangedAttack = self.CanRangedAttack",
    "_oldAttackRange = self.AttackRange",
    "return self.altcondition ~= nil and self.altcondition(self.inst) or true",
}

for _, fragment in ipairs(forbidden) do
    assert(source:find(fragment, 1, true) == nil,
        "Unsafe legacy compatibility pattern remains: " .. fragment)
end

print("weapon compatibility contract: OK")
