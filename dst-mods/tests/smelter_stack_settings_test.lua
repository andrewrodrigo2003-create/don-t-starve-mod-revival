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
        io.write("PASS  ", name, "\\n")
    else
        failed = failed + 1
        io.write("FAIL  ", name, " (expected ", tostring(expected), ", got ", tostring(actual), ")\\n")
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

io.write("\\n", passed, " passed; ", failed, " failed\\n")
if failed > 0 then os.exit(1) end
