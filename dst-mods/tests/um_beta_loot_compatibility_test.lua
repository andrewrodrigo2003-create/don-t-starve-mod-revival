local config = {
    mam_extra_drops = true,
    mam_drops_normalise = false,
    mam_drops_mode = 1,
    mam_allow_third_party_drop_overrides = false,
    mam_drop_hounds = 1,
    mam_drop_firehound = 1,
    mam_drop_icehound = 1,
}

package.preload["mam/config"] = function()
    return {
        on = function(key) return config[key] == true end,
        int = function(key, default)
            local value = config[key]
            return type(value) == "number" and value or default
        end,
    }
end

package.preload["mam/log"] = function()
    return {
        WarnOnce = function() end,
        Error = function() end,
        Guarded = function(_, fn) return fn end,
    }
end

local original_global = GLOBAL
GLOBAL = { TheWorld = { ismastersim = true }, UMCommonFns = nil }

package.loaded["mam/config"] = nil
package.loaded["mam/log"] = nil
package.loaded["mam/loot_guard"] = nil
local guard = require("mam/loot_guard")

local callbacks = {}
guard.Init(function(prefab, fn)
    callbacks[prefab] = fn
end)

guard.Declare("firehound", "firehound", {
    { "redgem_shard", 1.00 },
    { "redgem_shard", 0.75 },
    { "redgem_shard", 0.50 },
    { "redgem_shard", 0.25 },
}, { skip_if_um = true, parent_key = "hounds" })

guard.Declare("icehound", "icehound", {
    { "bluegem_shard", 1.00 },
    { "bluegem_shard", 0.75 },
    { "bluegem_shard", 0.50 },
    { "bluegem_shard", 0.25 },
}, { skip_if_um = true, parent_key = "hounds" })

local function run(prefab)
    local additions = {}
    local inst = {
        components = {
            lootdropper = {
                AddChanceLoot = function(_, item, chance)
                    additions[#additions + 1] = { item = item, chance = chance }
                end,
            },
        },
    }
    callbacks[prefab](inst)
    return additions
end

assert(guard.HasUncompromising() == false)
local no_um_fire = run("firehound")
local no_um_ice = run("icehound")
assert(#no_um_fire == 4 and no_um_fire[1].item == "redgem_shard")
assert(#no_um_ice == 4 and no_um_ice[1].item == "bluegem_shard")

-- The Public Beta publishes GLOBAL.UMCommonFns from its modmain.lua.
GLOBAL.UMCommonFns = {}
assert(guard.HasUncompromising() == true)

-- Auto + additive: leave the Beta's red/blue gem hound loot alone.
config.mam_drop_hounds = 1
config.mam_drops_mode = 1
config.mam_allow_third_party_drop_overrides = false
assert(#run("firehound") == 0)
assert(#run("icehound") == 0)

-- Always + additive: intentionally stack MAM shards with the Beta's gems.
config.mam_drop_hounds = 2
assert(#run("firehound") == 4)
assert(#run("icehound") == 4)

-- Rewrite + Auto still yields to UM; Rewrite + Always is explicit opt-in.
config.mam_drops_mode = 2
config.mam_allow_third_party_drop_overrides = true
config.mam_drop_hounds = 1
assert(#run("firehound") == 0)
assert(#run("icehound") == 0)
config.mam_drop_hounds = 2
assert(#run("firehound") == 4)
assert(#run("icehound") == 4)

GLOBAL = original_global
io.write("UM Public Beta hound-loot compatibility: Auto/Always/Rewrite passed\n")
