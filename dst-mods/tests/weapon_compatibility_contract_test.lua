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

assert(weapon_source:find("local wrapped_state_name, wrapped_target_time = state_name, target_time", 1, true),
    "stategraph loop must capture a fresh state name and target time per callback")
assert(weapon_source:find("self.states[wrapped_state_name]", 1, true),
    "stategraph callback must use the captured state name")

local forbidden = {
    "function self:SetProjectile",
    "self.altprojectile",
    "self._projectile",
    "function self:CanRangedAttack",
    "old_can_ranged_attack",
    "self.projectile =",
    "SetSpellFn",
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

-- A failing third-party reticule hook must not skip vanilla onexit cleanup.
-- The hook error is rethrown after cleanup so it remains diagnosable.
local interrupt_failure_cleanup_called = false
local interrupt_failure_state = {
    onexit = function()
        interrupt_failure_cleanup_called = true
        return "cleaned-after-interrupt-error"
    end,
}
local interrupt_failure_equip = {
    components = {
        reticule_spawner = {
            Interrupt = function()
                error("simulated reticule interruption failure")
            end,
        },
    },
}
stategraph_wrappers.WrapCastState(interrupt_failure_state, 1, function()
    return interrupt_failure_equip
end)
local interrupt_failure_inst = {
    sg = { statemem = { tm = 0, trgt = 1, equip = interrupt_failure_equip } },
}
local interrupt_ok, interrupt_err = pcall(interrupt_failure_state.onexit, interrupt_failure_inst)
assert(not interrupt_ok and tostring(interrupt_err):find("simulated reticule interruption failure", 1, true),
    "reticule interruption failure must remain visible")
assert(interrupt_failure_cleanup_called,
    "reticule interruption failure must not skip vanilla onexit cleanup")

-- onenter must still run vanilla setup when the optional equipment getter fails.
local getter_old_enter_called = false
local getter_error_state = {
    onenter = function()
        getter_old_enter_called = true
        return "vanilla-entered", nil, "tail"
    end,
}
stategraph_wrappers.WrapCastState(getter_error_state, 1, function()
    error("simulated equipment getter failure")
end)
local getter_ok, getter_error = pcall(getter_error_state.onenter, { sg = { statemem = {} } })
assert(not getter_ok and tostring(getter_error):find("simulated equipment getter failure", 1, true),
    "equipment getter failure must remain visible")
assert(getter_old_enter_called, "equipment getter failure must not skip vanilla onenter")

-- Wrapping the same state twice must not double-advance or interrupt it.
local idempotent_state = { onupdate = function() return "once" end }
assert(stategraph_wrappers.WrapCastState(idempotent_state, 1, function() return nil end),
    "first wrapper should install")
assert(stategraph_wrappers.WrapCastState(idempotent_state, 1, function() return nil end) == false,
    "second wrapper should be rejected")
assert(idempotent_state.onupdate({ sg = { statemem = {} } }, 0.5) == "once",
    "idempotent wrapper must call original once")

print("stategraph wrapper contract: OK (arguments, returns, cleanup and guards preserved)")

local mod_root = "dst-mods/metals_and_reforged/"
local function prefab_environment(enabled, mastersim, durability, foreign_api)
    local postinits, component_hooks = {}, {}
    local sandbox = setmetatable({
        TUNING = { ELECTRIC_DAMAGE_MULT = 1.5 },
        STRINGS = { NAMES = {}, RECIPE_DESC = {} },
        ACTIONS = { ATTACK = {}, CASTAOE = {} },
        TheWorld = { ismastersim = mastersim },
        EntityScript = { GetDisplayName = function() return "original-name" end },
        FRAMES = 1 / 30,
        Asset = function(kind, path) return { type = kind, file = path } end,
        resolvefilepath = function(path) return path end,
        MakeInventoryPhysics = function(inst) inst.inventoryphysics = true end,
        AddClassPostConstruct = function() end,
        AddPlayerPostInit = function() end,
        AddStategraphPostInit = function() end,
        AddRecipeTab = function() return {} end,
    }, { __index = _G })
    sandbox._G, sandbox.GLOBAL, sandbox.env = sandbox, sandbox, sandbox
    local original_name = sandbox.EntityScript.GetDisplayName
    local original_cast = function() return "original-cast" end
    sandbox.ACTIONS.CASTAOE.strfn = original_cast
    if foreign_api then
        sandbox.DAMAGETYPES = { PHYSICAL = "foreign-physical" }
    end
    local original_types = sandbox.DAMAGETYPES
    function sandbox.Class(base, constructor)
        local class = { _ctor = constructor }
        class.__index = class
        return setmetatable(class, {
            __index = base,
            __call = function(self, ...)
                local instance = setmetatable({}, self)
                constructor(instance, ...)
                return instance
            end,
        })
    end
    sandbox.Prefab = sandbox.Class(nil, function(self, name, fn, assets, dependencies)
        self.name, self.fn, self.assets, self.dependencies = name, fn, assets, dependencies
    end)
    function sandbox.modimport(path)
        return setfenv(assert(loadfile(mod_root .. path)), sandbox)()
    end
    function sandbox.require(name)
        if name == "class" or name == "util" then return end
        if name == "mod_prefab" then return sandbox.modimport("scripts/mod_prefab.lua") end
        return require(name)
    end
    function sandbox.GetModConfigData(name, default)
        if name == "legacy_forge_weapon_abilities" then return enabled end
        if name:match("_DURABILITY$") then return durability end
        if name:match("_DURABILITY_NORMAL$") then return 2 end
        if name:match("_DAMAGE$") then return default + 3 end
        return default
    end
    function sandbox.AddComponentPostInit(name, fn) component_hooks[name] = fn end
    function sandbox.AddPrefabPostInit(name, fn) postinits[name] = fn end
    local function setfield(field)
        return function(self, value) self[field] = value end
    end
    local function animation()
        return {
            SetBank = setfield("bank"), SetBuild = setfield("build"),
            PlayAnimation = setfield("animation"),
            OverrideSymbol = function(self, symbol, build, image) self.swap = { symbol, build, image } end,
            Show = function(self, symbol) self[symbol] = true end,
            Hide = function(self, symbol) self[symbol] = false end,
        }
    end
    function sandbox.CreateEntity()
        local inst = { components = {}, replica = {}, tags = {}, AnimState = animation() }
        inst.entity = {
            AddTransform = function() end, AddAnimState = function() end,
            AddSoundEmitter = function() end, AddNetwork = function() end,
            SetPristine = function() inst.pristine = true end,
        }
        function inst:AddTag(tag) self.tags[tag] = true end
        function inst:RemoveTag(tag) self.tags[tag] = nil end
        function inst:HasTag(tag) return self.tags[tag] == true end
        function inst:Remove() self.removed = true end
        function inst:AddComponent(name)
            assert(mastersim or name == "aoetargeting", "client added server component: " .. name)
            local component = { inst = self }
            if name == "weapon" then
                component.SetDamage, component.SetOnAttack = setfield("damage"), setfield("onattack")
                if component_hooks.weapon then component_hooks.weapon(component) end
                if foreign_api then
                    component.SetDamageType = function() error("foreign damage API must not activate MAM abilities") end
                    component.SetAltAttack = component.SetDamageType
                end
            elseif name == "equippable" then
                component.SetOnEquip, component.SetOnUnequip = setfield("onequip"), setfield("onunequip")
            elseif name == "aoetargeting" then
                component.reticule = {}
                component.SetEnabled, component.SetRange = setfield("enabled"), setfield("range")
                component.SetAlwaysValid = setfield("alwaysvalid")
            elseif name == "aoespell" then
                component.SetAOESpell = setfield("spell")
                component.OnSpellCast = setfield("caster")
            elseif name == "aoeweapon_leap" or name == "aoeweapon_lunge" then
                component.SetStimuli, component.SetWidth = setfield("stimuli"), setfield("width")
                component.SetOnLeapFn, component.SetOnLungeFn = setfield("onleap"), setfield("onlunge")
            elseif name == "rechargeable" then
                component.SetChargeTime = setfield("chargetime")
                component.Discharge = setfield("discharged")
                component.SetOnDischargedFn, component.SetOnChargedFn = setfield("ondischarged"), setfield("oncharged")
            elseif name == "reticule_spawner" then
                component.Setup = function(self, ...) self.setup = { ... } end
            elseif name == "parryweapon" then
                component.SetOnParryStartFn = setfield("onparrystart")
            elseif name == "helmsplitter" then
                component.SetOnHelmSplitFn = setfield("onhelmsplit")
            elseif name == "finiteuses" then
                component.consumption = {}
                component.SetMaxUses, component.SetUses = setfield("total"), setfield("current")
                component.SetOnFinished = setfield("onfinished")
                function component:SetConsumption(action, amount) self.consumption[action] = amount end
            else
                assert(name == "inspectable" or name == "inventoryitem" or name == "multithruster",
                    "unexpected component: " .. name)
            end
            self.components[name] = component
        end
        return inst
    end
    sandbox.modimport("initialise/modded_forgepack.lua")
    if not enabled then
        assert(next(component_hooks) == nil, "disabled abilities must not register global component hooks")
        assert(sandbox.EntityScript.GetDisplayName == original_name, "disabled abilities replaced display names")
        assert(sandbox.ACTIONS.CASTAOE.strfn == original_cast, "disabled abilities replaced CASTAOE")
        assert(sandbox.DAMAGETYPES == original_types, "disabled abilities changed damage globals")
    end
    return sandbox, postinits
end

local prefab_cases = {
    { "forginghammer", "hammer_mjolnir", "hammer_mjolnir", "swap_hammer_mjolnir", "hammer", "combat_leap" },
    { "pithpike", "spear_gungnir", "spear_gungnir", "swap_spear_gungnir", "pointy", "combat_lunge" },
    { "spiralspear", "spear_lance", "spear_lance", "swap_spear_lance", "pointy", "combat_superjump" },
    { "blacksmith_edge", "lavaarena_heavyblade", "sword_buster", "swap_sword_buster", "sharp" },
}
local ability_components = {
    "aoetargeting", "aoespell", "aoeweapon_leap", "aoeweapon_lunge", "rechargeable",
    "reticule_spawner", "parryweapon", "helmsplitter", "multithruster",
}
local prefab_passed, prefab_failures = 0, {}
for _, mode in ipairs({ { enabled = false }, { enabled = true }, { enabled = false, foreign = true } }) do
    for _, mastersim in ipairs({ false, true }) do
        for _, durability in ipairs({ 0, 80 }) do
            for _, data in ipairs(prefab_cases) do
                local success, message = pcall(function()
                    local sandbox, postinits = prefab_environment(mode.enabled, mastersim, durability, mode.foreign)
                    local prefab = sandbox.modimport("scripts/prefabs/" .. data[1] .. ".lua")
                    assert(prefab.name == data[1], "saved prefab identity changed")
                    local inst = prefab.fn()
                    inst.prefab = prefab.name
                    postinits[prefab.name](inst)
                    assert(inst.pristine and inst.inventoryphysics, "network/physics setup lost")
                    assert(inst.nameoverride == data[2] and inst.AnimState.bank == data[3]
                        and inst.AnimState.build == data[3], "weapon appearance changed")
                    assert(inst:HasTag(data[5]), "normal weapon tag lost")
                    if not mode.enabled then
                        for _, name in ipairs(ability_components) do
                            assert(inst.components[name] == nil, "disabled ability component remains: " .. name)
                        end
                        for _, tag in ipairs({ "aoeweapon_leap", "aoeweapon_lunge", "superjump", "parryweapon" }) do
                            assert(not inst:HasTag(tag), "disabled ability tag remains: " .. tag)
                        end
                    else
                        assert(inst.components.aoetargeting ~= nil, "opt-in targeting lost")
                    end
                    if mastersim then
                        local tuning = sandbox.TUNING.THE_FORGE_ITEM_PACK[data[1]:upper()]
                        assert(inst.components.weapon.damage == tuning.DAMAGE, "configured melee damage changed")
                        assert(inst.components.inventoryitem.imagename == data[2], "inventory image changed")
                        local owner = sandbox.CreateEntity()
                        local victim = sandbox.CreateEntity()
                        local spark_hit = false
                        sandbox.SpawnPrefab = function(name)
                            assert(name == "weaponsparks_fx", "normal attack triggered alternate effects")
                            return { SetPosition = function(_, attacker, target)
                                assert(attacker == owner and target == victim)
                                spark_hit = true
                            end }
                        end
                        if data[1] ~= "blacksmith_edge" then
                            inst.components.weapon.onattack(inst, owner, victim)
                            assert(spark_hit, "normal attack feedback lost")
                        end
                        inst.components.equippable.onequip(inst, owner)
                        assert(owner.AnimState.swap[2] == data[4] and owner.AnimState.ARM_carry,
                            "normal equip visuals lost")
                        inst.components.equippable.onunequip(inst, owner)
                        assert(owner.AnimState.ARM_normal and not owner:HasTag("stronggrip"), "unequip cleanup lost")
                        if durability > 0 then
                            local uses = inst.components.finiteuses
                            assert(uses.total == durability and uses.current == durability, "configured durability changed")
                            assert(uses.consumption[sandbox.ACTIONS.ATTACK] == 2, "normal attack wear changed")
                            assert(uses.consumption[sandbox.ACTIONS.CASTAOE]
                                == durability * tuning.DURABILITY.CONSUMPTION_SPECIAL / 100,
                                "special attack wear changed")
                            uses.onfinished(inst)
                            assert(inst.removed, "worn-out weapon must still be removed")
                        else
                            assert(inst.components.finiteuses == nil, "unlimited durability setting changed")
                        end
                        if mode.enabled then
                            local charge = inst.components.rechargeable
                            assert(charge.chargetime == tuning.COOLDOWN, "configured cooldown changed")
                            charge.ondischarged(inst)
                            assert(inst.components.aoetargeting.enabled == false)
                            charge.oncharged(inst)
                            assert(inst.components.aoetargeting.enabled == true)
                            assert(type(inst.components.aoespell.spell) == "function", "opt-in spell lost")
                            function owner:PushEvent(event, payload) self.event, self.payload = event, payload end
                            local position = {}
                            if data[6] then
                                inst.components.aoespell.spell(inst, owner, position)
                                assert(owner.event == data[6] and owner.payload.targetpos == position
                                    and owner.payload.weapon == inst, "opt-in cast event changed")
                                assert(inst.components.weapon.altdamage == tuning.ALT_DAMAGE, "alternate damage changed")
                            else
                                assert(inst.components.parryweapon.duration == tuning.PARRY_DURATION)
                                assert(inst.components.helmsplitter.damage == tuning.HELMSPLIT_DAMAGE)
                                function inst:GetAngleToPoint(point) assert(point == position) return 90 end
                                inst.components.aoespell.spell(inst, owner, position)
                                assert(owner.event == "combat_parry" and owner.payload.direction == 90
                                    and owner.payload.duration == tuning.PARRY_DURATION
                                    and owner.payload.weapon == inst, "opt-in parry event changed")
                                assert(charge.discharged == tuning.COOLDOWN
                                    and inst.components.aoespell.caster == owner, "parry cooldown/cast notification lost")
                            end
                        end
                    else
                        assert(inst.components.weapon == nil and inst.components.finiteuses == nil,
                            "client constructed authoritative weapon components")
                    end
                end)
                if success then
                    prefab_passed = prefab_passed + 1
                else
                    local label = data[1] .. " legacy=" .. tostring(mode.enabled) .. " server=" .. tostring(mastersim)
                        .. " durability=" .. durability .. " foreign=" .. tostring(mode.foreign)
                    prefab_failures[#prefab_failures + 1] = label .. ": " .. tostring(message)
                    print("FAIL: " .. prefab_failures[#prefab_failures])
                end
            end
        end
    end
end
print("weapon prefab runtime: " .. prefab_passed .. " passed / " .. #prefab_failures .. " failed (DST stubs)")
assert(#prefab_failures == 0, "weapon prefab gate regressions remain")

print("weapon compatibility contract: OK (legacy projectile hook removed; melee/AOE retained)")
