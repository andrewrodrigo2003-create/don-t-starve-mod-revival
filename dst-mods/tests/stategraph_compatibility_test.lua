-- StateGraph registration and cross-mod collision contracts for MAM.
-- Clean-room model based on public DST stategraph.lua source; L2/L3 only.
package.path = "dst-mods/tests/?.lua;dst-mods/tests/?/init.lua;" .. package.path
local StateGraph = require("simulator.core.stategraph")

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

local vanilla_states = {
    attack = { name = "attack", owner = "vanilla" },
    idle = { name = "idle", owner = "vanilla" },
    heavyattack = { name = "heavyattack", owner = "vanilla" },
}
local vanilla_handlers = {
    ATTACK = { destination = "attack", owner = "vanilla" },
}

local function make_graph(name)
    local graph = StateGraph.new(name, vanilla_states, vanilla_handlers)
    graph:RegisterModState("MetalsAndMore", "heavyattack", {
        name = "heavyattack", owner = "MetalsAndMore",
    })
    graph:RegisterModActionHandler("MetalsAndMore", "ATTACK", {
        destination = "heavyattack", owner = "MetalsAndMore",
    })
    graph:RegisterModState("WoodieSkillTree", "lucy_throw", {
        name = "lucy_throw", owner = "WoodieSkillTree",
    })
    graph:RegisterModActionHandler("WoodieSkillTree", "LUCY_THROW", {
        destination = "lucy_throw", owner = "WoodieSkillTree",
    })
    return graph
end

local distinct = make_graph("wilson"):Build({ "MetalsAndMore", "WoodieSkillTree" })
local distinct_attack = distinct:ResolveAction("ATTACK")
local distinct_lucy = distinct:ResolveAction("LUCY_THROW")
check("distinct action IDs coexist in one StateGraph",
    distinct_attack == "heavyattack" and distinct_lucy == "lucy_throw")

local mam_last = make_graph("wilson"):Build({ "WoodieSkillTree", "MetalsAndMore" })
local woodie_first = make_graph("wilson"):Build({ "MetalsAndMore", "WoodieSkillTree" })
check("same action ID resolves to the handler applied last (MAM last)",
    mam_last:ResolveAction("ATTACK") == "heavyattack")
check("same action ID resolves to the handler applied last (character mod last)",
    woodie_first:ResolveAction("ATTACK") == "attack")

-- A second registration under the same mod is appended and applied in order.
local repeated = StateGraph.new("wilson", vanilla_states, vanilla_handlers)
repeated:RegisterModActionHandler("OneMod", "ATTACK", { destination = "attack", owner = "first" })
repeated:RegisterModActionHandler("OneMod", "ATTACK", { destination = "heavyattack", owner = "second" })
repeated:Build({ "OneMod" })
check("multiple registrations within one mod preserve append order",
    repeated.actionhandlers.ATTACK.owner == "second")

-- State names are also keyed; duplicate names replace the prior definition.
local duplicate_state = StateGraph.new("wilson", vanilla_states, vanilla_handlers)
duplicate_state:RegisterModState("FirstMod", "heavyattack", { name = "heavyattack", owner = "first" })
duplicate_state:RegisterModState("SecondMod", "heavyattack", { name = "heavyattack", owner = "second" })
duplicate_state:Build({ "FirstMod", "SecondMod" })
check("duplicate state names replace the previous keyed definition",
    duplicate_state:GetState("heavyattack").owner == "second")

local reverse_state = StateGraph.new("wilson", vanilla_states, vanilla_handlers)
reverse_state:RegisterModState("FirstMod", "heavyattack", { name = "heavyattack", owner = "first" })
reverse_state:RegisterModState("SecondMod", "heavyattack", { name = "heavyattack", owner = "second" })
reverse_state:Build({ "SecondMod", "FirstMod" })
check("state-name collision result changes with mod traversal order",
    reverse_state:GetState("heavyattack").owner == "first")

local server = make_graph("wilson"):Build({ "MetalsAndMore" })
local client = make_graph("wilson_client"):Build({ "WoodieSkillTree" })
check("server and client StateGraphs resolve independently",
    server:ResolveAction("ATTACK") == "heavyattack"
        and client:ResolveAction("ATTACK") == "attack")

local invalid = StateGraph.new("wilson", vanilla_states, {})
invalid:RegisterModActionHandler("BrokenMod", "BROKEN_ACTION", {
    destination = "missing_custom_state",
})
invalid:Build({ "BrokenMod" })
local invalid_destination, invalid_reason = invalid:ResolveAction("BROKEN_ACTION")
check("handler pointing to a missing state is detected",
    invalid_destination == nil and invalid_reason == "missing_state:missing_custom_state")

local rejected = StateGraph.new("wilson", vanilla_states, {})
rejected:RegisterModActionHandler("ConditionalMod", "CONDITIONAL", {
    destination = "attack",
    condition = function(context) return context ~= nil and context.allowed == true end,
})
rejected:Build({ "ConditionalMod" })
local rejected_state, rejected_reason = rejected:ResolveAction("CONDITIONAL", { allowed = false })
check("handler condition rejection is represented without falling through to another handler",
    rejected_state == nil and rejected_reason == "condition_rejected")

local no_handler, no_handler_reason = distinct:ResolveAction("UNKNOWN_ACTION")
check("unknown action preserves the no-handler path",
    no_handler == nil and no_handler_reason == "no_handler")

local report = string.format("StateGraph compatibility: %d passed, %d failed", passed, failed)
print(report)
if failed > 0 then error(report) end
