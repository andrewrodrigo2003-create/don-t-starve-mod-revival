-- Regression contract for bounded ATTACK-until-dead behavior.
local ROOT = assert(os.getenv("DST_RUNTIME_ROOT"), "DST_RUNTIME_ROOT is required")
package.path = ROOT .. "/dst-mods/modxpector/scripts/?.lua;" .. package.path

ACTIONS = { ATTACK = { name = "ATTACK" } }
BufferedAction = function(doer, target, action, invobject, position)
    return { doer = doer, target = target, action = action, invobject = invobject, pos = position }
end
local current_time = 0
GetTime = function() return current_time end
Vector3 = function(x, y, z) return { x = x, y = y, z = z } end

local function run_attack(initial_health, max_repeats, repeat_timeout, hold_buffered, two_targets)
    current_time = 0
    local health = initial_health
    local attacks = 0
    local current_buffered
    local enemy = {
        prefab = "spider",
        IsValid = function() return true end,
        HasTag = function(_, tag) return tag == "monster" end,
        Transform = { GetWorldPosition = function() return 3, 0, 4 end },
        replica = { health = { GetCurrent = function() return health end } },
    }
    local second_health = 100
    local second_enemy = {
        prefab = "spider",
        IsValid = function() return true end,
        HasTag = function(_, tag) return tag == "monster" end,
        Transform = { GetWorldPosition = function() return 9, 0, 0 end },
        replica = { health = { GetCurrent = function() return second_health end } },
    }
    TheSim = { FindEntities = function() return two_targets and { enemy, second_enemy } or { enemy } end }
    local player = {
        prefab = "wilson",
        IsValid = function() return true end,
        ListenForEvent = function() end,
        Transform = { GetWorldPosition = function() return 0, 0, 0 end },
        components = {
            playercontroller = {
                DoAction = function(_, action)
                    if action.action == ACTIONS.ATTACK and action.target == enemy then
                        attacks = attacks + 1
                        health = health - 15
                        if hold_buffered then current_buffered = action end
                    end
                end,
            },
        },
        GetBufferedAction = function() return current_buffered end,
        DoTaskInTime = function(_, delay, callback)
            current_time = current_time + (delay or 0)
            callback()
        end,
    }

    local report
    local VirtualPlayer = require("modxpector/virtual_player_client")
    local controller = VirtualPlayer.new(player, {
        allowed_prefabs = { "spider" },
        on_finished = function(value) report = value end,
    })
    local plan = {
        schema = "modxpector/test-plan/v1",
        enabled = true,
        steps = {
            { kind = "assert", assertion = { kind = "target_dead", target = { prefab = "spider" }, expected = false } },
            { kind = "action", action = "ATTACK", target = { prefab = "spider" }, target_required = true,
                repeat_until_target_dead = true, max_repeats = max_repeats, repeat_timeout = repeat_timeout, timeout = 5 },
        },
    }
    plan.steps[#plan.steps + 1] = {
        kind = "assert",
        assertion = { kind = "target_dead", target = { prefab = "spider" } },
        verifies_step = 2,
    }
    assert(controller:Start(plan))
    assert(report ~= nil, "Virtual Player did not finish")
    return report, health, attacks, controller, second_health
end

local success, health, attacks, controller = run_attack(25, 3, 5)
assert(success.outcome == "passed" and success.failure == nil)
assert(health <= 0 and attacks == 2)
assert(success.assertions_total == 2 and success.assertions_passed == 2)
assert(not pcall(function() controller:ResolveTarget({ prefab = "hound" }) end))
assert(not pcall(function() controller:ResolveTarget({ tag = "monster" }) end))
local locked_report, locked_health, locked_attacks, _, untouched_health = run_attack(25, 3, 5, false, true)
assert(locked_report.outcome == "passed")
assert(locked_health <= 0 and locked_attacks == 2)
assert(untouched_health == 100, "repeat attack retargeted another same-prefab entity")

local max_failure, max_health, max_attacks = run_attack(100, 2, 5)
assert(max_failure.outcome == "failed" and max_failure.failure == "target not defeated within max_repeats")
assert(max_health == 70 and max_attacks == 2)

local timeout_failure, timeout_health, timeout_attacks = run_attack(1000, 20, 1)
assert(timeout_failure.outcome == "failed" and timeout_failure.failure == "attack repeat timeout")
assert(timeout_health > 0 and timeout_health < 1000 and timeout_attacks < 20)

local stuck_failure, stuck_health, stuck_attacks = run_attack(1000, 20, 1, true)
assert(stuck_failure.outcome == "failed" and stuck_failure.failure == "attack repeat timeout")
assert(stuck_health == 985 and stuck_attacks == 1)

print("MODXPECTOR_VIRTUAL_PLAYER_ATTACK_REPEAT_OK success_attacks=" .. tostring(attacks)
    .. " max_attacks=" .. tostring(max_attacks) .. " timeout_attacks=" .. tostring(timeout_attacks)
    .. " stuck_action_attacks=" .. tostring(stuck_attacks) .. " locked_target_attacks=" .. tostring(locked_attacks))
