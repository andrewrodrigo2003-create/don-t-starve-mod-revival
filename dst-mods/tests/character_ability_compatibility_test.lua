-- Character ability compatibility contracts for Metals and More Reforged.
-- The Willow path is modeled from the documented DST willow_ember Spellbook /
-- server spell / projectile flow. It is not execution of Klei's runtime scripts.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local Simulator = require("simulator.bootstrap")

local function read(path)
    local file = assert(io.open(path, "r"), "cannot read " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local mace = read("dst-mods/metals_and_reforged/initialise/modded_mace.lua")
local shears = read("dst-mods/metals_and_reforged/initialise/modded_shearsharvest.lua")
local forgepack = read("dst-mods/metals_and_reforged/initialise/modded_forgepack.lua")
local actions = read("dst-mods/metals_and_reforged/initialise/modded_actions.lua")
local bernie = read("dst-mods/metals_and_reforged/initialise/modded_stronger_bernie.lua")

local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

-- Static audit of the real MAM hooks that can overlap character action paths.
check("MAM heavy-weapon hook is scoped to ACTIONS.ATTACK",
    mace:find("ActionHandler%(ACTIONS%.ATTACK", 1) ~= nil)
check("MAM heavy-weapon hook registers server and client Wilson graphs",
    mace:find('AddStategraphActionHandler%("wilson"', 1) ~= nil
        and mace:find('AddStategraphActionHandler%("wilson_client"', 1) ~= nil)
check("MAM does not directly register a spellbook-cast stategraph handler",
    mace:find("CAST_SPELLBOOK", 1, true) == nil
        and actions:find("CAST_SPELLBOOK", 1, true) == nil)
check("MAM harvest wrapper forwards extra arguments to the previous handler",
    actions:find("OldHarvestfn%(act, %.%.%.%)", 1) ~= nil)
check("MAM shear controller wrapper preserves the previous action when no area-pick action exists",
    shears:find("local old_action", 1, true) ~= nil
        and shears:find("new_action ~= nil and new_action or old_action", 1, true) ~= nil)
check("MAM CASTAOE change is a display string function, not a new stategraph handler",
    forgepack:find("ACTIONS.CASTAOE.strfn", 1, true) ~= nil
        and forgepack:find("AddStategraphActionHandler%(.-CASTAOE") == nil)
check("MAM explicitly patches Willow and Bernie combat callbacks",
    bernie:find('AddPrefabPostInit%("willow"', 1) ~= nil
        and bernie:find('AddPrefabPostInit%("bernie_active"', 1) ~= nil
        and bernie:find("DoAreaAttack", 1, true) ~= nil)

-- Minimal documented Spellbook -> server SpellCaster -> projectile pipeline.
-- This tests the integration contract and failure ordering, not the actual
-- implementation of willow_ember.lua from the game installation.
local function make_projectile()
    local projectile = { thrown = false }
    projectile.components = {
        projectile = {
            Throw = function(self, owner, target, attacker)
                if target == nil or target.valid == false then return false end
                projectile.thrown = true
                projectile.owner = owner
                projectile.target = target
                projectile.attacker = attacker
                return true
            end,
        },
    }
    return projectile
end

local function make_willow(role, embers, spawn_ok)
    local willow = { role = role, valid = true }
    local ember = { stack = embers, cost = 2 }
    local spawned = 0
    local spellbook = {
        items = { { id = "firethrow", name = "Fire Throw" } },
        selected = nil,
        Open = function(self) self.open = true end,
        Select = function(self, id) self.selected = id end,
    }
    local function cast_spell(user, target)
        if role ~= "server" then return false, "not_authority" end
        if ember.stack < ember.cost then return false, "not_enough_embers" end
        if target == nil or target.valid == false then return false, "no_target" end
        if not spawn_ok then return false, "spawn_failed" end
        local projectile = make_projectile()
        spawned = spawned + 1
        if not projectile.components.projectile:Throw(user, target, user) then
            return false, "projectile_rejected"
        end
        ember.stack = ember.stack - ember.cost
        return true, projectile
    end
    return {
        willow = willow,
        ember = ember,
        spellbook = spellbook,
        cast = cast_spell,
        spawned = function() return spawned end,
    }
end

local client = make_willow("client", 4, true)
client.spellbook:Open()
client.spellbook:Select("firethrow")
local client_cast, client_reason = client.cast(client.willow, { valid = true })
check("Willow client can select Fire Throw but cannot authoritatively cast",
    client.spellbook.open == true
        and client.spellbook.selected == "firethrow"
        and client_cast == false
        and client_reason == "not_authority"
        and client.ember.stack == 4)

local willow = make_willow("server", 4, true)
local target = { valid = true }
local cast_ok, projectile = willow.cast(willow.willow, target)
check("Willow Fire Throw launches a projectile on the server",
    cast_ok == true and projectile.thrown == true
        and projectile.owner == willow.willow
        and projectile.target == target)
check("Willow consumes embers only after successful projectile launch",
    willow.ember.stack == 2 and willow.spawned() == 1)

local poor_willow = make_willow("server", 1, true)
local poor_ok, poor_reason = poor_willow.cast(poor_willow.willow, { valid = true })
check("insufficient embers reject Willow spell without consuming resources",
    poor_ok == false and poor_reason == "not_enough_embers"
        and poor_willow.ember.stack == 1 and poor_willow.spawned() == 0)

local spawn_willow = make_willow("server", 4, false)
local spawn_ok_result, spawn_reason = spawn_willow.cast(spawn_willow.willow, { valid = true })
check("projectile spawn failure does not consume Willow embers",
    spawn_ok_result == false and spawn_reason == "spawn_failed"
        and spawn_willow.ember.stack == 4 and spawn_willow.spawned() == 0)

local target_willow = make_willow("server", 4, true)
local target_ok, target_reason = target_willow.cast(target_willow.willow, { valid = false })
check("invalid target rejects Willow spell without consuming embers",
    target_ok == false and target_reason == "no_target"
        and target_willow.ember.stack == 4 and target_willow.spawned() == 0)

-- Woodie/Lucy action identity remains unknown until the Workshop source is
-- supplied. The dedicated StateGraph compatibility suite now models the
-- source-backed registration/build/lookup behavior rather than a toy table.
check("MAM ATTACK registration is present; external Lucy action remains unverified",
    mace:find("ActionHandler%(ACTIONS%.ATTACK", 1) ~= nil)

-- Verify that the shared network contract can carry server spell state to client.
local server_net = Simulator.Network.new("server")
local client_net = Simulator.Network.new("client")
assert(server_net:Set("willow_spell_active", true))
assert(client_net:ApplySnapshot(server_net:Snapshot()))
check("server spell state can replicate to client without client-side authority",
    client_net:Get("willow_spell_active") == true
        and not client_net:Set("willow_spell_active", false))


-- Execute MAM's real Willow/Bernie post-init wrappers with controlled combat
-- fixtures. This checks callback composition and guards, not animation/physics.
local prefab_postinits = {}
GLOBAL = {
    setmetatable = setmetatable,
    rawget = rawget,
}
env = {}
TheWorld = { ismastersim = true }
local nearby_entities = {}
TheSim = {
    FindEntities = function() return nearby_entities end,
}
AddPrefabPostInit = function(prefab, fn)
    prefab_postinits[prefab] = fn
end
dofile("dst-mods/metals_and_reforged/initialise/modded_stronger_bernie.lua")

local function make_combatant(prefab, health)
    local inst = {
        prefab = prefab,
        components = {
            health = {
                currenthealth = health,
                SetMaxHealth = function(self, value) self.maxhealth = value end,
            },
            combat = {
                last_damage = nil,
                GetAttacked = function(self, attacker, damage)
                    self.last_damage = damage
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

local active_bernie = make_combatant("bernie_active", 500)
prefab_postinits.bernie_active(active_bernie)
active_bernie.components.combat:GetAttacked({}, 100)
check("MAM Bernie Active damage wrapper executes without error",
    active_bernie.components.combat.last_damage == 75)

local willow_actor = make_combatant("willow", 100)
nearby_entities = { active_bernie }
prefab_postinits.willow(willow_actor)
willow_actor.components.combat:GetAttacked({}, 100)
check("MAM Willow combat wrapper detects nearby injured Bernie",
    willow_actor.components.combat.last_damage == 75)

local big_bernie = make_combatant("bernie_big", 3000)
prefab_postinits.bernie_big(big_bernie)
local area_target = make_combatant("target_primary", 100)
local area_secondary = make_combatant("target_secondary", 100)
area_target.Transform.GetWorldPosition = function() return 0, 0, 0 end
nearby_entities = { area_target, area_secondary }
local hit_count = big_bernie.components.combat:DoAreaAttack(area_target, 4)
check("MAM Bernie Big area attack runs through its replacement callback",
    hit_count == 1 and area_secondary.components.combat.last_damage == 54)
check("MAM Bernie Big combat wrapper initializes its configured health and damage",
    big_bernie.components.health.maxhealth == 3200
        and big_bernie.components.combat.defaultdamage == 56)

print("\nCharacter ability contracts: " .. passed .. " passed; " .. failed .. " failed")
if failed > 0 then os.exit(1) end
