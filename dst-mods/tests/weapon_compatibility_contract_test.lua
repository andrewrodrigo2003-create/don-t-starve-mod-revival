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
    'require("mam/stategraph_wrappers")',
    "MAMStategraphWrappers.WrapCastState",
    "return old_deststate(inst, action, ...)",
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

-- Stategraph wrappers must preserve vanilla callback contracts and cleanup.
package.path = "dst-mods/metals_and_reforged/scripts/?.lua;" .. package.path
local stategraph_wrappers = require("mam/stategraph_wrappers")

local reticule = {
    interrupts = 0,
    Interrupt = function(self)
        self.interrupts = self.interrupts + 1
    end,
}
local equipped = { components = { reticule_spawner = reticule } }
local callback_calls = {}
local cast_state = {
    onenter = function(inst, data, token)
        callback_calls.enter = { data, token }
        return "entered", token
    end,
    onexit = function(inst, reason, token)
        callback_calls.exit = { reason, token }
        return "exited", token
    end,
    onupdate = function(inst, dt, token)
        callback_calls.update = { dt, token }
        return "updated", token
    end,
}
local caster = {
    sg = { statemem = {} },
    equipped = equipped,
}
assert(stategraph_wrappers.WrapCastState(cast_state, 1, function(inst)
    return inst.equipped
end), "cast state wrapper should install")

local enter_data = { spell = "test" }
local enter_result, enter_token = cast_state.onenter(caster, enter_data, "enter-token")
assert(enter_result == "entered" and enter_token == "enter-token",
    "onenter must preserve original return values")
assert(caster.sg.statemem.tm == 0 and caster.sg.statemem.trgt == 1
    and caster.sg.statemem.equip == equipped, "onenter must initialize cast timing/equipment")
assert(callback_calls.enter[1] == enter_data and callback_calls.enter[2] == "enter-token",
    "onenter must forward all original arguments")

local update_result, update_token = cast_state.onupdate(caster, 0.4, "update-token")
assert(update_result == "updated" and update_token == "update-token",
    "onupdate must preserve original return values")
assert(caster.sg.statemem.tm == 0.4, "onupdate must advance cast time")
assert(callback_calls.update[1] == 0.4 and callback_calls.update[2] == "update-token",
    "onupdate must forward dt and extra arguments")

local exit_result, exit_token = cast_state.onexit(caster, "exit-reason", "exit-token")
assert(exit_result == "exited" and exit_token == "exit-token",
    "onexit must preserve original return values")
assert(reticule.interrupts == 1, "incomplete cast must interrupt reticule")
assert(callback_calls.exit[1] == "exit-reason" and callback_calls.exit[2] == "exit-token",
    "onexit must forward all original arguments")

-- Missing equipment must never bypass the original vanilla onexit cleanup.
local no_equip_exit_called = false
local no_equip_state = {
    onexit = function()
        no_equip_exit_called = true
        return "cleaned"
    end,
}
stategraph_wrappers.WrapCastState(no_equip_state, 1, function() return nil end)
local no_equip_inst = { sg = { statemem = { tm = 0, trgt = 1, equip = nil } } }
assert(no_equip_state.onexit(no_equip_inst) == "cleaned",
    "no-equip onexit must return original result")
assert(no_equip_exit_called, "no-equip onexit must still call vanilla cleanup")

-- Completed casts do not interrupt their reticule.
local completed_reti = { interrupts = 0, Interrupt = function(self) self.interrupts = self.interrupts + 1 end }
local completed_equip = { components = { reticule_spawner = completed_reti } }
local completed_state = { onexit = function() return "done" end }
stategraph_wrappers.WrapCastState(completed_state, 1, function()
    return completed_equip
end)
local completed_inst = { sg = { statemem = { tm = 1.2, trgt = 1, equip = completed_equip } } }
assert(completed_state.onexit(completed_inst) == "done", "completed onexit should call original")
assert(completed_reti.interrupts == 0, "completed cast should not interrupt reticule")

local no_reticule_state = { onexit = function() return "no-reticule" end }
local no_reticule_equip = { components = {} }
stategraph_wrappers.WrapCastState(no_reticule_state, 1, function()
    return no_reticule_equip
end)
local no_reticule_inst = { sg = { statemem = { tm = 0, trgt = 1, equip = no_reticule_equip } } }
assert(no_reticule_state.onexit(no_reticule_inst) == "no-reticule",
    "missing reticule component must not block original cleanup")

-- Missing state/callbacks and missing sg must be safe.
assert(stategraph_wrappers.WrapCastState(nil, 1, function() end) == false,
    "nil state should be rejected")
local empty_state = {}
assert(stategraph_wrappers.WrapCastState(empty_state, 1, function() return nil end),
    "empty state should accept wrapper")
empty_state.onenter({})
empty_state.onupdate({}, 0.5)
empty_state.onexit({})

print("stategraph wrapper contract: OK (arguments, returns, cleanup and guards preserved)")

print("weapon compatibility contract: OK (legacy projectile hook removed; melee/AOE retained)")
