-- Regression contract for removing the legacy alternate-projectile hook
-- while retaining Metals and More's melee alternate attacks and Forge abilities.
-- Run from the repository root with Lua 5.1.

local function read(path)
    local file, err = io.open(path, "r")
    assert(file ~= nil, "Could not open " .. path .. ": " .. tostring(err))
    local source = file:read("*a")
    file:close()
    return source
end

local weapon_source = read("dst-mods/metals_and_reforged/scripts/mod_main.lua")

local required = {
    "function self:SetAltAttack(X, Y, _legacy_projectile, q, a7, a8)",
    "function self:SetIsAltAttacking(aa)",
    "function self:HasAltAttack()",
    "function self:CanAltAttack()",
    "function self:DoAltAttack(G, T, U, x, V)",
    "self.damagetype = self.altdamagetype",
    "local old_calc_damage = self.CalcDamage",
    "local old_do_attack = self.DoAttack",
    "local old_get_attacked = self.GetAttacked",
    "return self.altcondition == nil or self.altcondition(self.inst)",
}

for _, fragment in ipairs(required) do
    assert(weapon_source:find(fragment, 1, true) ~= nil,
        "Missing retained weapon compatibility contract: " .. fragment)
end

local forbidden = {
    "function self:SetProjectile",
    "self.altprojectile",
    "self._projectile",
    "function self:CanRangedAttack",
    "old_can_ranged_attack",
    "self.projectile =",
}

for _, fragment in ipairs(forbidden) do
    assert(weapon_source:find(fragment, 1, true) == nil,
        "Legacy alternate-projectile hook remains: " .. fragment)
end

local forge_contracts = {
    {
        path = "dst-mods/metals_and_reforged/scripts/prefabs/forginghammer.lua",
        required = {
            "components.aoespell:SetAOESpell",
            "components.aoeweapon_leap:SetOnLeapFn",
            "components.weapon:SetDamage",
        },
    },
    {
        path = "dst-mods/metals_and_reforged/scripts/prefabs/pithpike.lua",
        required = {
            "components.aoespell:SetAOESpell",
            "components.aoeweapon_lunge:SetOnLungeFn",
            "components.weapon:SetAltAttack",
        },
    },
    {
        path = "dst-mods/metals_and_reforged/scripts/prefabs/spiralspear.lua",
        required = {
            "components.aoespell:SetAOESpell",
            "components.aoeweapon_leap:SetOnLeapFn",
            "components.weapon:SetAltAttack",
        },
    },
    {
        path = "dst-mods/metals_and_reforged/scripts/prefabs/blacksmith_edge.lua",
        required = {
            "components.aoespell:SetAOESpell",
            "components.parryweapon",
            "components.weapon:SetDamage",
        },
    },
}

for _, contract in ipairs(forge_contracts) do
    local source = read(contract.path)
    for _, fragment in ipairs(contract.required) do
        assert(source:find(fragment, 1, true) ~= nil,
            contract.path .. " lost retained Forge behavior: " .. fragment)
    end
end

assert(not weapon_source:lower():find("lucy", 1, true),
    "Metals and More weapon extension unexpectedly references Lucy")

print("weapon compatibility contract: OK (legacy projectile hook removed; melee/AOE retained)")
