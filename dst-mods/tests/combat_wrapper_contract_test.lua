-- Combat wrapper contracts: preserve multi-return values, trailing arguments,
-- area damage multipliers and temporary damage overrides.
local helpers = dofile("dst-mods/metals_and_reforged/scripts/mam/combat_wrapper_helpers.lua")

local combat = { damage_override = 17 }
local first, middle, last = helpers.WithDamageOverride(combat, 42, function(self, marker)
    assert(self.damage_override == 42)
    return "attack", nil, marker
end, "tail")
assert(first == "attack" and middle == nil and last == "tail",
    "damage override helper must preserve all return values")
assert(combat.damage_override == 17, "damage override must restore the previous value")

local ok, err = pcall(function()
    helpers.WithDamageOverride(combat, 99, function(self)
        assert(self.damage_override == 99)
        error("simulated attack failure")
    end)
end)
assert(not ok and tostring(err):find("simulated attack failure", 1, true),
    "damage override helper must rethrow callback failures")
assert(combat.damage_override == 17, "damage override must restore state after callback failure")

assert(helpers.AreaDamageMultiplier(nil, 1, 1) == 1,
    "default area damage must remain at 100 percent")
assert(helpers.AreaDamageMultiplier(0.5, 2, 3) == 3,
    "area damage must multiply area percent, additive and multiplicative buffs")

assert(helpers.ApplyAltDamage(10, 10, 0, 20) == 20,
    "alt damage must scale relative to nonzero base damage")
assert(helpers.ApplyAltDamage(10, 0, 0, 20) == 20,
    "alt damage must remain finite when the base damage is zero")
assert(helpers.ApplyAltDamage(12, 10, 2, nil) == 12,
    "missing override must fall back to the original base damage")

local modmain = assert(io.open("dst-mods/metals_and_reforged/scripts/mod_main.lua", "r"))
local source = modmain:read("*a")
modmain:close()
local function contains(fragment, description)
    assert(source:find(fragment, 1, true), description)
end
contains('local MAMCombatWrapperHelpers = _G.require("mam/combat_wrapper_helpers")',
    "active combat wrapper must load its tested helper")
contains("local C, spdamage = old_calc_damage(self, A, z, B)",
    "CalcDamage must retain special damage")
contains("return C, spdamage", "CalcDamage must return special damage")
contains("function self:DoAttack(T, z, U, x, V, ...)",
    "DoAttack must accept trailing vanilla arguments")
contains("old_do_attack(self, T, z, U, x, W, ...)",
    "DoAttack must forward trailing vanilla arguments")
contains("function self:GetAttacked(G, X, z, x, spdamage, ...)",
    "GetAttacked must accept special damage")
contains("old_get_attacked(self, G, X, z, x, spdamage, ...)",
    "GetAttacked must forward special damage and trailing arguments")
contains("function self:DoAreaAttack(A, Y, z, Z, x, excludetags, onlyontarget, ...)",
    "DoAreaAttack must support onlyontarget")
contains("AreaDamageMultiplier", "DoAreaAttack must use the tested multiplier helper")
contains("target.components.combat:GetAttacked(self.inst, damage, z, x, spdamage)",
    "area attacks must forward special damage")
contains("WithDamageOverride(self, C", "special attacks must use scoped damage override")

local bernie = assert(io.open("dst-mods/metals_and_reforged/initialise/modded_stronger_bernie.lua", "r"))
local bernie_source = bernie:read("*a")
bernie:close()
assert(bernie_source:find("function(self, attacker, damage, weapon, stimuli, spdamage, ...)", 1, true),
    "Bernie damage wrappers must preserve special damage")
assert(bernie_source:find("_doAreaAttack(self, target, range, weapon, validfn, stimuli, excludetags, onlyontarget, ...)", 1, true),
    "Bernie area wrapper must preserve onlyontarget semantics")
assert(bernie_source:find('if select("#", ...) > 0 then', 1, true),
    "Bernie area wrapper must delegate unknown trailing arguments")
assert(bernie_source:find('not (leaders and leaders:HasTag("player"))', 1, true),
    "Bernie area wrapper must preserve its player-follower exclusion")

print("combat wrapper contract: OK (spdamage, varargs, area multiplier, scoped override)")
