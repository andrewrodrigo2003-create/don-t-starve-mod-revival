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
contains("C, spdamage = old_calc_damage(self, A, z, B)",
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

package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path
local components, replicas = {}, {}
local globals = {
    require = require,
    FRAMES = 1 / 30,
    TUNING = { THE_FORGE_ITEM_PACK = {} },
    STRINGS = { NAME_DETAIL_EXTENTION = { FORGE_DETAIL = "Forge detail" } },
    EntityScript = {},
}
function globals.EntityScript:GetAdjectivedName()
    return "Name"
end
function globals.EntityScript:GetDisplayName()
    return "Previous mod name", "previous-result"
end
local environment = setmetatable({
    _G = globals,
    TUNING = globals.TUNING,
    AddComponentPostInit = function(name, fn) components[name] = fn end,
    AddClassPostConstruct = function(name, fn) replicas[name] = fn end,
    AddPrefabPostInit = function() end,
    AddPlayerPostInit = function() end,
    AddStategraphPostInit = function() end,
}, { __index = _G })
setfenv(assert(loadfile("dst-mods/metals_and_reforged/scripts/mod_main.lua")), environment)()

local passed, failures = 0, {}
local function scenario(name, fn)
    local success, message = pcall(fn)
    if success then
        passed = passed + 1
    else
        failures[#failures + 1] = name .. ": " .. tostring(message)
        print("FAIL: " .. failures[#failures])
    end
end

local function new_combat()
    local instance = { components = {} }
    local weapon = { altattackrange = 6, althitrange = 2, CanAltAttack = function() return true end }
    local item = { components = { weapon = weapon } }
    local component = {
        inst = instance,
        attackrange = 3,
        GetWeapon = function() return item end,
        GetAttackRange = function() return 4 end,
        GetHitRange = function(self) return self.temprange or 9 end,
    }
    components.combat(component)
    return component, weapon
end

scenario("temporary vanilla range takes precedence over alternate range", function()
    local component = new_combat()
    component.temprange = 12
    assert(component:GetHitRange() == 12)
    component.temprange = 0
    assert(component:GetHitRange() == 0)
    component.temprange = nil
    assert(component:GetHitRange() == 5)
    assert(component:GetAttackRange() == 6)
end)
scenario("alternate range fallbacks preserve previous range methods", function()
    local component, weapon = new_combat()
    weapon.altattackrange, weapon.althitrange = nil, nil
    assert(component:GetAttackRange() == 4)
    assert(component:GetHitRange() == 9)
    weapon.altattackrange, weapon.althitrange = 0, 0
    assert(component:GetAttackRange() == 0)
    assert(component:GetHitRange() == 3)
    weapon.CanAltAttack = function() return false end
    assert(component:GetAttackRange() == 4 and component:GetHitRange() == 9)
    component.GetWeapon = function() return nil end
    assert(component:GetAttackRange() == 4 and component:GetHitRange() == 9)
end)

local function new_damage_combat()
    local trace = { calls = 0, active = true, special = { planar = 7 }, weapon_multiplier = 1 }
    local target = { HasTag = function() return false end }
    local item = { components = {} }
    local weapon = { altdamage = 20, CanAltAttack = function() return trace.active end }
    item.components.weapon = weapon
    local component = { inst = { components = {} }, damagebonus = 2, defaultdamage = 10 }
    weapon.damage = function(inst, attacker, victim)
        assert(inst == item and attacker == component.inst)
        trace.calls = trace.calls + 1
        if trace.onbase then trace.onbase(victim) end
        return victim.base or 10
    end
    function weapon:GetDamage(attacker, victim)
        local base = type(self.damage) == "function" and self.damage(item, attacker, victim) or self.damage
        return base * trace.weapon_multiplier
    end
    function component:CalcDamage(victim, held, multiplier)
        if trace.bypass then return 77, trace.special end
        local base = held.components.weapon:GetDamage(self.inst, victim)
        if trace.fail then error("base calculation failure") end
        return base * 3 * (multiplier or 1) + self.damagebonus, trace.special
    end
    components.combat(component)
    return component, item, target, trace
end
scenario("ordinary dynamic damage is evaluated once and keeps special damage", function()
    local component, item, target, trace = new_damage_combat()
    trace.active = false
    local original = item.components.weapon.damage
    local damage, special = component:CalcDamage(target, item, 2)
    assert(damage == 62 and special == trace.special)
    assert(trace.calls == 1 and item.components.weapon.damage == original)
end)
scenario("alternate dynamic damage preserves vanilla and weapon multipliers", function()
    local component, item, target, trace = new_damage_combat()
    trace.weapon_multiplier = 2
    local original = item.components.weapon.damage
    local damage, special = component:CalcDamage(target, item, 2)
    assert(damage == 242, "alternate damage must retain all base damage multipliers")
    assert(special == trace.special and trace.calls == 1)
    assert(item.components.weapon.damage == original)
end)
scenario("alternate default reuses the dynamic base without a second evaluation", function()
    local component, item, target, trace = new_damage_combat()
    item.components.weapon.altdamage = item.components.weapon.damage
    local damage, special = component:CalcDamage(target, item)
    assert(damage == 32 and special == trace.special)
    assert(trace.calls == 1)
end)
scenario("dynamic zero base retains the established alternate damage policy", function()
    local component, item, target, trace = new_damage_combat()
    target.base = 0
    assert(component:CalcDamage(target, item) == 22)
    assert(trace.calls == 1)
end)
scenario("damage capture restores the callback after calculation errors", function()
    local component, item, target, trace = new_damage_combat()
    local original = item.components.weapon.damage
    trace.fail = true
    local success, message = pcall(component.CalcDamage, component, target, item)
    assert(not success and tostring(message):find("base calculation failure", 1, true))
    assert(item.components.weapon.damage == original and trace.calls == 1)
end)
scenario("damage capture preserves deliberate callback replacement", function()
    local component, item, target, trace = new_damage_combat()
    trace.onbase = function() item.components.weapon.damage = 17 end
    assert(component:CalcDamage(target, item) == 62)
    assert(item.components.weapon.damage == 17 and trace.calls == 1)
end)
scenario("nested alternate calculations keep their own captured base damage", function()
    local component, item, target, trace = new_damage_combat()
    local original = item.components.weapon.damage
    local nested = { base = 4, HasTag = target.HasTag }
    local nested_damage
    trace.onbase = function(victim)
        if victim == target then nested_damage = component:CalcDamage(nested, item) end
    end
    assert(component:CalcDamage(target, item) == 62 and nested_damage == 62)
    assert(trace.calls == 2 and item.components.weapon.damage == original)
end)
scenario("previous damage overrides need not evaluate the weapon callback", function()
    local component, item, target, trace = new_damage_combat()
    trace.bypass = true
    local original = item.components.weapon.damage
    local damage, special = component:CalcDamage(target, item)
    assert(damage == 77 and special == trace.special and trace.calls == 0)
    assert(item.components.weapon.damage == original)
end)
scenario("numeric alternate damage keeps the existing scaling", function()
    local component, item, target, trace = new_damage_combat()
    item.components.weapon.damage = 10
    assert(component:CalcDamage(target, item) == 62 and trace.calls == 0)
end)

local function new_equippable()
    local owner = { components = {} }
    local trace = {}
    owner.components.buffable = {
        AddBuff = function(_, key, buffs)
            assert(key == "equipment" and buffs.cooldown_mult == -0.25)
            trace.buffed = true
        end,
        RemoveBuff = function(_, key)
            assert(key == "equipment")
            trace.buffed = false
        end,
    }
    local component = { inst = { prefab = "equipment" } }
    function component:Equip(wearer, ...)
        assert(wearer == owner and trace.buffed == true)
        trace.equip = { n = select("#", ...), ... }
        return "equipped", nil, "previous-result"
    end
    function component:Unequip(wearer, ...)
        assert(wearer == owner and trace.buffed == false)
        trace.unequip = { n = select("#", ...), ... }
        return "unequipped", nil, "previous-result"
    end
    components.equippable(component)
    component.uniquebuffs.cooldown_mult = -0.25
    return component, owner, trace
end
scenario("equipment wrapper forwards from_ground and previous return values", function()
    local component, owner, trace = new_equippable()
    for _, from_ground in ipairs({ true, false }) do
        local result, middle, token = component:Equip(owner, from_ground, "tail")
        assert(trace.equip.n == 2 and trace.equip[1] == from_ground and trace.equip[2] == "tail")
        assert(result == "equipped" and middle == nil and token == "previous-result")
    end
end)
scenario("unequip wrapper preserves trailing arguments and return values", function()
    local component, owner, trace = new_equippable()
    component:Equip(owner, true)
    local result, middle, token = component:Unequip(owner, "tail")
    assert(trace.unequip.n == 1 and trace.unequip[1] == "tail")
    assert(result == "unequipped" and middle == nil and token == "previous-result")
end)

local function new_replica(server)
    local active, permitted = true, true
    local component = { altattackrange = 6, CanAltAttack = function() return permitted end }
    local replica = {
        inst = { components = server and { weapon = component } or {} },
        classified = {
            isaltattacking = { value = function() return active end },
            altattackrange = { value = function() return 6 end },
        },
        AttackRange = function() return 3 end,
    }
    replicas["components/inventoryitem_replica"](replica)
    return replica, function(allow, attacking) permitted, active = allow, attacking end
end

scenario("server replica delegates without indexing replica.components", function()
    local replica = new_replica(true)
    assert(replica.components == nil)
    assert(replica:CanAltAttack() == true)
    assert(replica:AttackRange() == 6)
end)
scenario("server denial never falls through to the client check", function()
    local replica, set = new_replica(true)
    replica:SetAltAttackCheck(function() error("server must not use client permission") end)
    set(false, true)
    assert(replica:CanAltAttack() == false)
    assert(replica:AttackRange() == 3)
    set(true, false)
    assert(not replica:CanAltAttack())
end)
scenario("client permission and missing classified keep vanilla fallback", function()
    local replica = new_replica(false)
    assert(replica:CanAltAttack() == true and replica:AttackRange() == 6)
    replica:SetAltAttackCheck(function(inst) assert(inst == replica.inst); return false end)
    assert(replica:AttackRange() == 3)
    replica.classified = nil
    assert(not replica:CanAltAttack() and replica:AttackRange() == 3)
end)

local function new_companion()
    local replica = {
        inst = { HasTag = function(_, tag) return tag == "companion" end },
        CanBeAttacked = function() return true, "previous-result" end,
    }
    replicas["components/combat_replica"](replica)
    return replica
end
local player = { HasTag = function(_, tag) return tag == "player" end }
scenario("companion option uses the Forge config namespace", function()
    globals.TUNING.THE_FORGE_ITEM_PACK = { PREVENT_COMPAGNION_ATTACK = true }
    assert(new_companion():CanBeAttacked(player) == false)
end)
scenario("companion exceptions preserve previous callback results", function()
    local replica = new_companion()
    globals.TUNING.THE_FORGE_ITEM_PACK = { PREVENT_COMPAGNION_ATTACK = false }
    local result, token = replica:CanBeAttacked(player)
    assert(result == true and token == "previous-result")
    globals.TUNING.THE_FORGE_ITEM_PACK = nil
    assert(replica:CanBeAttacked(player) == true)
    globals.TUNING.THE_FORGE_ITEM_PACK = { PREVENT_COMPAGNION_ATTACK = true }
    assert(replica:CanBeAttacked(nil) == true)
    assert(replica:CanBeAttacked({ HasTag = function() return false end }) == true)
    replica.inst.HasTag = function() return false end
    assert(replica:CanBeAttacked(player) == true)
end)

scenario("display name preserves previous mods for ordinary items", function()
    local entity = setmetatable({ prefab = "ordinary_item" }, { __index = globals.EntityScript })
    local name, token = entity:GetDisplayName()
    assert(name == "Previous mod name" and token == "previous-result")
    entity.nameoverride = "unknown_detail"
    assert(entity:GetDisplayName() == "Previous mod name")
end)
scenario("display name retains Forge override detail", function()
    local entity = setmetatable({ prefab = "forge_item", nameoverride = "forge_detail" },
        { __index = globals.EntityScript })
    assert(entity:GetDisplayName() == "Name\nForge detail")
end)

local function new_event_entity(prefab)
    local entity = { prefab = prefab, components = {}, listeners = {} }
    function entity:ListenForEvent(event, fn, source)
        source = source or self
        source.listeners = source.listeners or {}
        source.listeners[event] = source.listeners[event] or {}
        table.insert(source.listeners[event], { owner = self, fn = fn })
    end
    function entity:RemoveEventCallback(event, fn, source)
        source = source or self
        local bucket = source.listeners and source.listeners[event]
        for index = #(bucket or {}), 1, -1 do
            if bucket[index].owner == self and bucket[index].fn == fn then
                table.remove(bucket, index)
            end
        end
        if bucket ~= nil and #bucket == 0 then source.listeners[event] = nil end
    end
    function entity:PushEvent(event, data)
        local callbacks = {}
        for _, listener in ipairs(self.listeners[event] or {}) do
            callbacks[#callbacks + 1] = listener.fn
        end
        for _, fn in ipairs(callbacks) do fn(self, data) end
    end
    return entity
end

local function new_rechargeable()
    local item = new_event_entity("rechargeable_item")
    item.starts, item.stops = 0, 0
    function item:StartUpdatingComponent() self.starts = self.starts + 1 end
    function item:StopUpdatingComponent() self.stops = self.stops + 1 end
    local component = { inst = item, updating = false, modifiers = { external = 0.2 } }
    function component:SetChargeTimeMod(source, key, value)
        assert(source == item and key == item.prefab)
        self.modifiers[key] = value ~= 0 and value or nil
    end
    function component:RemoveChargeTimeMod(source, key)
        assert(source == item and key == item.prefab)
        self.modifiers[key] = nil
    end
    components.rechargeable(component)
    return component, item
end

scenario("rechargeable accepts an owner without the MAM buff component", function()
    local component, item = new_rechargeable()
    local owner = new_event_entity("npc")
    item:PushEvent("equipped", { owner = owner })
    owner:PushEvent("equip", { item = item })
    assert(component.modifiers[item.prefab] == nil)
    assert(component.modifiers.external == 0.2)
    item:PushEvent("unequipped", { owner = owner })
    assert(component.owner == nil)
end)
scenario("rechargeable preserves player cooldown modifiers and cleanup", function()
    local component, item = new_rechargeable()
    local owner = { components = { buffable = { GetBuffData = function(_, key)
        assert(key == "cooldown_mult")
        return -0.25
    end } } }
    item:PushEvent("equipped", { owner = owner })
    assert(component.modifiers[item.prefab] == -0.25)
    item:PushEvent("unequipped", { owner = owner })
    assert(component.modifiers[item.prefab] == nil and component.modifiers.external == 0.2)
    assert(item.listeners.equip == nil and item.listeners.unequip == nil)
    item:PushEvent("equipped", { owner = { components = {} } })
    assert(component.modifiers[item.prefab] == nil)
end)
scenario("equip does not take ownership of vanilla recharge scheduling", function()
    local component, item = new_rechargeable()
    local owner = { components = { buffable = { GetBuffData = function() return 0 end } } }
    item:PushEvent("equipped", { owner = owner })
    assert(item.starts == 0 and component.updating == false)
    component.updating = true
    item:PushEvent("unequipped", { owner = owner })
    assert(item.stops == 0 and component.updating == true)
end)

scenario("owner equipment events refresh the aggregate cooldown modifier", function()
    local component, item = new_rechargeable()
    local owner = new_event_entity("player")
    local bonus = 0
    owner.components.buffable = { GetBuffData = function() return bonus end }
    item:PushEvent("equipped", { owner = owner })
    owner:PushEvent("equip", { item = item, eslot = "hands" })
    local hat = new_event_entity("cooldown_hat")
    bonus = -0.25
    owner:PushEvent("equip", { item = hat, eslot = "head" })
    assert(component.modifiers[item.prefab] == -0.25, "owner equip must update the item modifier")
    bonus = -0.10
    owner:PushEvent("unequip", { item = hat, eslot = "head" })
    assert(component.modifiers[item.prefab] == -0.10, "unequip must retain remaining equipment bonuses")
    bonus = 0
    owner:PushEvent("unequip", { item = new_event_entity("cooldown_armor"), eslot = "body" })
    assert(component.modifiers[item.prefab] == nil and component.modifiers.external == 0.2)
    assert(item.starts == 0 and item.stops == 0)
end)
scenario("moving rechargeable equipment detaches the previous owner listeners", function()
    local component, item = new_rechargeable()
    local first_owner = new_event_entity("first_player")
    local second_owner = new_event_entity("second_player")
    first_owner.components.buffable = { GetBuffData = function() return -0.25 end }
    second_owner.components.buffable = { GetBuffData = function() return -0.10 end }
    item:PushEvent("equipped", { owner = first_owner })
    assert(first_owner.listeners.equip ~= nil and first_owner.listeners.unequip ~= nil)
    item:PushEvent("unequipped", { owner = first_owner })
    assert(first_owner.listeners.equip == nil and first_owner.listeners.unequip == nil)
    first_owner:PushEvent("unequip", { item = item })
    assert(component.modifiers[item.prefab] == nil)
    item:PushEvent("equipped", { owner = second_owner })
    first_owner:PushEvent("equip", { item = new_event_entity("old_owner_hat") })
    assert(component.modifiers[item.prefab] == -0.10)
    item:PushEvent("unequipped", { owner = second_owner })
    assert(second_owner.listeners.equip == nil and second_owner.listeners.unequip == nil)
    item:PushEvent("equipped", { owner = second_owner })
    assert(#second_owner.listeners.equip == 1 and #second_owner.listeners.unequip == 1)
end)
scenario("multiple rechargeable items keep independent owner subscriptions", function()
    local first, first_item = new_rechargeable()
    local second, second_item = new_rechargeable()
    local owner = new_event_entity("player")
    local bonus = -0.25
    owner.components.buffable = { GetBuffData = function() return bonus end }
    first_item:PushEvent("equipped", { owner = owner })
    second_item:PushEvent("equipped", { owner = owner })
    bonus = -0.10
    owner:PushEvent("unequip", { item = new_event_entity("cooldown_hat") })
    assert(first.modifiers[first_item.prefab] == -0.10 and second.modifiers[second_item.prefab] == -0.10)
    first_item:PushEvent("unequipped", { owner = owner })
    assert(#owner.listeners.equip == 1 and #owner.listeners.unequip == 1)
    bonus = -0.20
    owner:PushEvent("equip", { item = new_event_entity("another_hat") })
    assert(first.modifiers[first_item.prefab] == nil)
    assert(second.modifiers[second_item.prefab] == -0.20)
    second_item:PushEvent("unequipped", { owner = owner })
    assert(owner.listeners.equip == nil and owner.listeners.unequip == nil)
end)

print(string.format("combat runtime hooks: %d scenarios passed / %d failed (DST stubs)", passed, #failures))
assert(#failures == 0, table.concat(failures, "\n"))
print("combat wrapper contract: OK (spdamage, varargs, area multiplier, scoped override)")
