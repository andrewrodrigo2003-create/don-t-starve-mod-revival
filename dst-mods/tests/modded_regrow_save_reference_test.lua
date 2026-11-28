-- Regression harness for preserving the reference list returned by chained OnSave callbacks.
local callbacks = {}

GLOBAL = {
    TILE_SCALE = 4,
    STRINGS = { NAMES = { MIGRATION_PORTAL = "migration_portal" } },
    TheNet = { GetIsServer = function() return true end },
}
WORLD_TILES = { DESERT_DIRT = 1, ROCKY = 2 }

AddPrefabPostInit = function(prefab, fn)
    callbacks[prefab] = fn
end

local function make_entity(on_save, on_load, ismastersim)
    return {
        components = {},
        ismastersim = ismastersim,
        OnSave = on_save,
        OnLoad = on_load,
        DoTaskInTime = function()
            return { Cancel = function() end }
        end,
        ListenForEvent = function() end,
    }
end

dofile("dst-mods/metals_and_reforged/initialise/modded_regrow.lua")

local function assert_true(value, message)
    if not value then
        error("FAIL: " .. message)
    end
end

local rock_refs = { "rock-reference" }
local rock_save_calls, rock_load_calls = 0, 0
local rock = make_entity(
    function(inst, data)
        rock_save_calls = rock_save_calls + 1
        data.base_rock_saved = true
        return rock_refs
    end,
    function()
        rock_load_calls = rock_load_calls + 1
    end,
    true
)

assert_true(type(callbacks.spikyrock) == "function", "spikyrock post-init registered")
callbacks.spikyrock(rock)

local rock_data = {}
local returned_rock_refs = rock.OnSave(rock, rock_data)
assert_true(returned_rock_refs == rock_refs, "rock OnSave preserves original reference list")
assert_true(rock_save_calls == 1, "rock original OnSave runs exactly once")
assert_true(rock_data.base_rock_saved == true, "rock original OnSave can still populate data")
assert_true(type(rock_data.simpleregrowth) == "table", "rock regrowth data is saved")

rock.OnLoad(rock, {})
assert_true(rock_load_calls == 1, "rock original OnLoad runs when regrowth data is absent")

local world_refs = { "world-reference" }
local world_save_calls, world_load_calls = 0, 0
local world = make_entity(
    function(inst, data)
        world_save_calls = world_save_calls + 1
        data.base_world_saved = true
        return world_refs
    end,
    function()
        world_load_calls = world_load_calls + 1
    end,
    true
)

assert_true(type(callbacks.world) == "function", "world post-init registered")
callbacks.world(world)

local world_data = {}
local returned_world_refs = world.OnSave(world, world_data)
assert_true(returned_world_refs == world_refs, "world OnSave preserves original reference list")
assert_true(world_save_calls == 1, "world original OnSave runs exactly once")
assert_true(world_data.base_world_saved == true, "world original OnSave can still populate data")

world.OnLoad(world, {})
assert_true(world_load_calls == 1, "world original OnLoad runs when regrowth data is absent")

print("Regrowth save reference preservation: 11 passed / 0 failed")
