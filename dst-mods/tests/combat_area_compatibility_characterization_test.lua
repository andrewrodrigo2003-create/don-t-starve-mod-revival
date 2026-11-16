-- Characterize the current Bernie Big DoAreaAttack override against the
-- public vanilla Combat:DoAreaAttack contract.
-- This test intentionally reports known divergences; it does not call them fixes.
local callbacks = {}
local query = nil
local returned_entities = {}

GLOBAL = {
    setmetatable = setmetatable,
    rawget = rawget,
}
env = {}
TheWorld = { ismastersim = true }
TheSim = {
    FindEntities = function(_, x, y, z, range, musttags, excludetags)
        query = {
            x = x, y = y, z = z, range = range,
            musttags = musttags, excludetags = excludetags,
        }
        return returned_entities
    end,
}
AddPrefabPostInit = function(prefab, fn) callbacks[prefab] = fn end

local function make_combatant(prefab)
    local inst = {
        prefab = prefab,
        components = {
            health = {
                currenthealth = 3000,
                SetMaxHealth = function(self, value) self.maxhealth = value end,
            },
            combat = {
                defaultdamage = 0,
                hits = {},
                GetAttacked = function(self, attacker, damage, weapon, stimuli)
                    self.hits[#self.hits + 1] = {
                        attacker = attacker, damage = damage,
                        weapon = weapon, stimuli = stimuli,
                    }
                    return true
                end,
                DoAreaAttack = function() return -1 end,
                SetDefaultDamage = function(self, value) self.defaultdamage = value end,
                SetAreaDamage = function(self, value) self.areahitrange = value end,
                IsValidTarget = function() return true end,
            },
        },
        Transform = {
            GetWorldPosition = function() return 0, 0, 0 end,
        },
    }
    inst.components.combat.inst = inst
    function inst:PushEvent() end
    return inst
end

dofile("dst-mods/metals_and_reforged/initialise/modded_stronger_bernie.lua")
local bernie = make_combatant("bernie_big")
callbacks.bernie_big(bernie)

local primary = make_combatant("primary_target")
local secondary = make_combatant("secondary_target")
secondary.Transform.GetWorldPosition = function() return 1, 0, 0 end
returned_entities = { secondary }
local weapon = { prefab = "test_weapon" }

-- Vanilla's public contract accepts onlyontarget as argument 7. When true,
-- vanilla attacks the primary target and does not perform a world entity scan.
bernie.components.combat:DoAreaAttack(primary, 4, weapon, nil, "fire", { "shadow" }, true)
local only_target_diverges = query ~= nil
    and #primary.components.combat.hits == 0
    and #secondary.components.combat.hits == 1

-- Vanilla passes caller-provided exclusion tags through to FindEntities.
local passed_excludes = query ~= nil and query.excludetags or {}
local caller_exclusion_ignored = true
for _, tag in ipairs(passed_excludes) do
    if tag == "shadow" then caller_exclusion_ignored = false end
end

-- The override still honors validfn and forwards weapon/stimuli to GetAttacked.
secondary.components.combat.hits = {}
bernie.components.combat:DoAreaAttack(primary, 4, weapon,
    function() return false end, "electric", { "shadow" })
local validfn_preserved = #secondary.components.combat.hits == 0

secondary.components.combat.hits = {}
bernie.components.combat:DoAreaAttack(primary, 4, weapon, nil, "electric", nil)
local hit = secondary.components.combat.hits[1]
local weapon_and_stimuli_preserved = hit ~= nil
    and hit.weapon == weapon and hit.stimuli == "electric"

print("KNOWN DIVERGENCE  Bernie Big override ignores vanilla onlyontarget=true: "
    .. tostring(only_target_diverges))
print("KNOWN DIVERGENCE  Bernie Big override substitutes caller excludetags: "
    .. tostring(caller_exclusion_ignored))
print("CONTRACT CHECK     Bernie Big override honors validfn: "
    .. tostring(validfn_preserved))
print("CONTRACT CHECK     Bernie Big override forwards weapon/stimuli: "
    .. tostring(weapon_and_stimuli_preserved))

assert(only_target_diverges, "expected current onlyontarget divergence was not reproduced")
assert(caller_exclusion_ignored, "expected current excludetags divergence was not reproduced")
assert(validfn_preserved, "validfn should be honored")
assert(weapon_and_stimuli_preserved, "weapon/stimuli should be forwarded")
print("Bernie Big area-attack characterization: 4 checks passed; 2 known divergences recorded")
