local MOD_ROOT = "dst-mods/metals_and_reforged/"
package.path = MOD_ROOT .. "scripts/?.lua;" .. package.path

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "expected true")
    end
end

local config_values = {
    mam_extra_drops = 1,
    mam_drops_mode = 1,
    mam_allow_third_party_drop_overrides = 1,
    mam_drops_normalise = 0,
    mam_drop_boulders = 1,
    mam_drop_stalagmites = 1,
    mam_drop_chess = 1,
    mam_drop_hounds = 1,
    mam_drop_marbletree = 1,
    mam_drop_shark = 1,
    mam_drop_marbleshrub = 1,
}

local MAMConfig = {
    on = function(key)
        local value = config_values[key]
        return value == true or value == 1
    end,
    int = function(key, default)
        local value = config_values[key]
        return value == nil and default or value
    end,
}

local MAMLog = {
    WarnOnce = function() end,
    Error = function(_, message) error(message) end,
    Info = function() end,
    Guarded = function(_, fn) return fn end,
    Try = function(_, fn, ...)
        return fn(...)
    end,
}

package.preload["mam/config"] = function() return MAMConfig end
package.preload["mam/log"] = function() return MAMLog end

GLOBAL = {
    TheWorld = { ismastersim = true },
    UMCommonFns = nil,
    require = require,
}
TheWorld = GLOBAL.TheWorld

local prefab_callbacks = {}
local simpost_callbacks = {}
local shared_tables = {}

function AddPrefabPostInit(name, fn)
    prefab_callbacks[name] = fn
end

function AddSimPostInit(fn)
    table.insert(simpost_callbacks, fn)
end

function Asset()
    return {}
end

function Prefab(name, fn)
    return { name = name, fn = fn }
end

function SetSharedLootTable(name, entries)
    shared_tables[name] = entries
end

local LootGuard = require("mam/loot_guard")

-- Load the actual declarations used by the mod, not a copied decision function.
dofile(MOD_ROOT .. "initialise/modded_drops.lua")

local function make_inst()
    local dropper = { items = {} }
    function dropper:AddChanceLoot(prefab, chance)
        table.insert(self.items, { prefab = prefab, chance = chance })
    end
    return { components = { lootdropper = dropper } }
end

local function run_prefab(name)
    local callback = prefab_callbacks[name]
    assert_true(callback ~= nil, "missing AddPrefabPostInit callback for " .. name)
    local inst = make_inst()
    callback(inst)
    return inst.components.lootdropper.items
end

-- Additive mode still applies ordinary sources, and the marble tree/shark
-- retain their historical entity-level rolls in Rewrite mode.
config_values.mam_drops_mode = 2
local marble_rewrite = run_prefab("marbletree")
local shark_rewrite = run_prefab("shark")
assert_eq(#marble_rewrite, 10, "marble tree Rewrite additive rolls")
assert_eq(#shark_rewrite, 2, "shark Rewrite additive rolls")
assert_eq(#run_prefab("firehound"), 0, "hounds Auto must defer to Rewrite table without UM")

-- Rewrite + UM: Auto yields to UM; Always adds our shard rolls without replacing
-- the UM's shared loot table.
GLOBAL.UMCommonFns = {}
config_values.mam_drop_hounds = 1
assert_eq(#run_prefab("firehound"), 0, "hounds Auto with UM")
config_values.mam_drop_hounds = 2
assert_eq(#run_prefab("firehound"), 4, "hounds Always with UM")

-- Additive mode + UM: Auto yields; Always adds. This is the legacy compatibility
-- path and must not duplicate the UM's own gem table by default.
config_values.mam_drops_mode = 1
config_values.mam_drop_hounds = 1
assert_eq(#run_prefab("firehound"), 0, "additive hounds Auto with UM")
config_values.mam_drop_hounds = 2
assert_eq(#run_prefab("firehound"), 4, "additive hounds Always with UM")

-- Master switch, source switch and client authority are enforced by the real module.
config_values.mam_extra_drops = 0
assert_eq(#run_prefab("shark"), 0, "master switch off")
config_values.mam_extra_drops = 1
config_values.mam_drop_shark = 0
assert_eq(#run_prefab("shark"), 0, "individual source switch off")
config_values.mam_drop_shark = 1
GLOBAL.TheWorld.ismastersim = false
assert_eq(#run_prefab("shark"), 0, "client must not apply loot")
GLOBAL.TheWorld.ismastersim = true

-- The real exported normalizer preserves relative weights while capping each
-- prefab's aggregate chance at 1.0.
config_values.mam_drops_normalise = 1
local normalized = LootGuard.PrepareEntries({
    { "gold_dust", 1.00 },
    { "gold_dust", 0.75 },
    { "iron_ore", 0.50 },
})
local gold_total = 0
for _, entry in ipairs(normalized) do
    if entry[1] == "gold_dust" then
        gold_total = gold_total + entry[2]
    end
end
assert_true(math.abs(gold_total - 1.0) < 0.000001, "normalizer should cap aggregate gold_dust chance")
config_values.mam_drops_normalise = 0

-- Per-source chance scaling affects only MAM's own rolls and is also used by Rewrite.
config_values.mam_drop_hounds_chance = 50
local half_chance = LootGuard.PrepareEntries({ { "redgem_shard", 0.8 } }, "hounds")
assert_true(math.abs(half_chance[1][2] - 0.4) < 0.000001, "source chance multiplier")
config_values.mam_drop_hounds_chance = 150
local increased_chance = LootGuard.PrepareEntries({ { "redgem_shard", 0.8 } }, "hounds")
assert_eq(increased_chance[1][2], 1, "chance scaling clamps individual rolls at 1.0")
config_values.mam_drop_hounds_chance = nil

-- Load the actual newrocks prefab file with the minimum DST registration stubs.
local rewrite_names = {
    "rock2", "rock_moon", "rock_moon_shell",
    "full_rock", "med_rock", "low_rock",
    "stalagmite_tall_full_rock", "stalagmite_tall_med_rock", "stalagmite_tall_low_rock",
    "chess_junk", "knight", "knight_nightmare", "rook", "rook_nightmare",
    "bishop", "bishop_nightmare", "hound_fire", "hound_cold",
}

local function load_rewrite_tables(overrides, has_um)
    config_values.mam_extra_drops = 1
    config_values.mam_drops_mode = 2
    config_values.mam_drops_normalise = 0
    config_values.mam_drop_boulders = 1
    config_values.mam_drop_stalagmites = 1
    config_values.mam_drop_chess = 1
    config_values.mam_drop_hounds = 1
    for key, value in pairs(overrides or {}) do
        config_values[key] = value
    end
    GLOBAL.UMCommonFns = has_um and {} or nil
    shared_tables = {}
    simpost_callbacks = {}
    dofile(MOD_ROOT .. "scripts/prefabs/newrocks.lua")
    for _, fn in ipairs(simpost_callbacks) do
        fn()
    end
    return shared_tables
end

local all_tables = load_rewrite_tables()
local present = 0
for _, name in ipairs(rewrite_names) do
    assert_true(all_tables[name] ~= nil, "Rewrite table missing: " .. name)
    present = present + 1
end
assert_eq(present, 18, "number of vanilla Rewrite tables")

local protected_tables = load_rewrite_tables({ mam_allow_third_party_drop_overrides = 0 })
assert_true(next(protected_tables) == nil, "third-party overwrite opt-out must preserve shared loot tables")
assert_eq(#run_prefab("rock2"), 2, "safe fallback keeps additive MAM boulder drops")

local no_boulders = load_rewrite_tables({ mam_drop_boulders = 0 })
assert_true(no_boulders.rock2 == nil and no_boulders.rock_moon == nil and no_boulders.rock_moon_shell == nil,
    "boulder source switch must gate all three tables")

local no_stalagmites = load_rewrite_tables({ mam_drop_stalagmites = 0 })
for _, name in ipairs({
    "full_rock", "med_rock", "low_rock",
    "stalagmite_tall_full_rock", "stalagmite_tall_med_rock", "stalagmite_tall_low_rock",
}) do
    assert_true(no_stalagmites[name] == nil, "stalagmite source switch must gate " .. name)
end

local no_chess = load_rewrite_tables({ mam_drop_chess = 0 })
for _, name in ipairs({
    "chess_junk", "knight", "knight_nightmare", "rook", "rook_nightmare", "bishop", "bishop_nightmare",
}) do
    assert_true(no_chess[name] == nil, "chess source switch must gate " .. name)
end

local no_hounds = load_rewrite_tables({ mam_drop_hounds = 0 })
assert_true(no_hounds.hound_fire == nil and no_hounds.hound_cold == nil,
    "hounds source switch must gate both hound tables")

local um_tables = load_rewrite_tables({}, true)
assert_true(um_tables.hound_fire == nil and um_tables.hound_cold == nil,
    "Rewrite hounds must not replace UM tables")

local disabled_tables = load_rewrite_tables({ mam_extra_drops = 0 })
for _, name in ipairs(rewrite_names) do
    assert_true(disabled_tables[name] == nil, "master switch must gate " .. name)
end

print("PASS: loot_guard + modded_drops + newrocks; independent overwrite opt-in, chance tuning, UM Auto/Always, normalization and 18 table gates")
