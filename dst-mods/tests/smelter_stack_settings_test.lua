-- Tests the stack-acceptance policy used by the smelter container widget.
-- Run from the repository root:
--   texlua dst-mods/tests/smelter_stack_settings_test.lua

local ROOT = "dst-mods/metals_and_reforged/scripts/"
package.path = ROOT .. "?.lua;" .. package.path

local settings = require("mam/container_settings")
local passed, failed = 0, 0

local function check(name, actual, expected)
    if actual == expected then
        passed = passed + 1
        io.write("PASS  ", name, "\n")
    else
        failed = failed + 1
        io.write("FAIL  ", name, " (expected ", tostring(expected), ", got ", tostring(actual), ")\n")
    end
end

local function instance(raw)
    return { mam_plan = { value = function() return raw end } }
end

check("server batch on overrides local off",
    settings.accepts_stacks(instance("c|1|10|25 p||1|idle"), false), true)
check("server batch off overrides local on",
    settings.accepts_stacks(instance("c|0|10|25 p||1|idle"), true), false)
check("missing netvar uses local fallback",
    settings.accepts_stacks({}, true), true)
check("missing netvar preserves local off",
    settings.accepts_stacks({}, false), false)
check("empty netvar uses local fallback",
    settings.accepts_stacks(instance(""), true), true)
check("malformed config uses local fallback",
    settings.accepts_stacks(instance("c|2|10|25 p||1|idle"), false), false)
check("truncated config uses local fallback",
    settings.accepts_stacks(instance("c|1|10"), false), false)
check("broken netvar getter uses local fallback",
    settings.accepts_stacks({ mam_plan = { value = function() error("not ready") end } }, true), true)

io.write("\n", passed, " passed; ", failed, " failed\n")
if failed > 0 then os.exit(1) end

-- Exercise the actual widget setup wrapper, not only the pure policy helper.
local function widget_accepts_stacks(local_batch, net_raw)
    local containers = {
        MAXITEMSLOTS = 0,
        widgetsetup = function() end,
    }
    local config = { on = function() return local_batch end }
    local smelting = { IsSmelterIngredient = function() return true end }
    local forecast = {
        button_text = function() return "Smelt" end,
        can_start = function() return true end,
    }

    GLOBAL = {
        RPC = {},
        TUNING = {},
        Vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
        ACTIONS = { SMELT = { code = 1, mod_name = nil } },
        BufferedAction = function() return { Do = function() end } end,
        SendRPCToServer = function() end,
        require = function(name)
            local modules = {
                smelting = smelting,
                containers = containers,
                ["mam/config"] = config,
                ["mam/forecast"] = forecast,
                ["mam/container_settings"] = settings,
            }
            return modules[name]
        end,
    }

    dofile("dst-mods/metals_and_reforged/initialise/modded_cookers.lua")

    local inst = {
        prefab = "smelter",
        mam_plan = net_raw ~= nil and {
            value = function() return net_raw end,
        } or nil,
    }
    local container = {
        inst = inst,
        SetNumSlots = function(self, count) self.numslots = count end,
    }
    containers.widgetsetup(container, "smelter", nil)
    return container.acceptsstacks, container.numslots
end

check("widget uses server batch-on despite local off",
    widget_accepts_stacks(false, "c|1|10|25 p||1|idle"), true)
check("widget uses server batch-off despite local on",
    widget_accepts_stacks(true, "c|0|10|25 p||1|idle"), false)
local fallback_on, slots_on = widget_accepts_stacks(true, nil)
check("widget falls back to local option before netvar", fallback_on, true)
check("widget keeps four furnace slots", slots_on, 4)
