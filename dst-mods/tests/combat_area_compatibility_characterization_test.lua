-- Verify the Bernie Big DoAreaAttack override preserves the public vanilla contract.
-- The legacy Forge ability system is opt-in; this test directly loads the Bernie override.
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
local only_target_honored = query == nil
    and #primary.components.combat.hits == 1
    and #secondary.components.combat.hits == 0

-- Vanilla passes caller-provided exclusion tags through to FindEntities.
query = nil
secondary.components.combat.hits = {}
bernie.components.combat:DoAreaAttack(primary, 4, weapon,
    function() return false end, "electric", { "shadow" })
local passed_excludes = query ~= nil and query.excludetags or {}
local caller_exclusion_preserved = false
for _, tag in ipairs(passed_excludes) do
    if tag == "shadow" then caller_exclusion_preserved = true end
end

-- The override still honors validfn.
local validfn_preserved = #secondary.components.combat.hits == 0

secondary.components.combat.hits = {}
bernie.components.combat:DoAreaAttack(primary, 4, weapon, nil, "electric", nil)
local hit = secondary.components.combat.hits[1]
local weapon_and_stimuli_preserved = hit ~= nil
    and hit.weapon == weapon and hit.stimuli == "electric"

print("CONTRACT CHECK     Bernie Big override honors onlyontarget=true: "
    .. tostring(only_target_honored))
print("CONTRACT CHECK     Bernie Big override preserves caller excludetags: "
    .. tostring(caller_exclusion_preserved))
print("CONTRACT CHECK     Bernie Big override honors validfn: "
    .. tostring(validfn_preserved))
print("CONTRACT CHECK     Bernie Big override forwards weapon/stimuli: "
    .. tostring(weapon_and_stimuli_preserved))

assert(only_target_honored, "onlyontarget=true must hit only the primary target")
assert(caller_exclusion_preserved, "caller exclusion tags must reach FindEntities")
assert(validfn_preserved, "validfn should be honored")
assert(weapon_and_stimuli_preserved, "weapon/stimuli should be forwarded")
print("Bernie Big area-attack compatibility: 4 checks passed; no known area-attack divergence remains")
