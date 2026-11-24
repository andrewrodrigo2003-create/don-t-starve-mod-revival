local ROOT = os.getenv("DST_RUNTIME_ROOT") or "."
local AI = dofile(ROOT .. "/dst-mods/modxpector/scripts/modxpector/embedded_ai.lua")

local function find_code(analysis, code)
    for _, finding in ipairs(analysis.findings or {}) do
        if finding.code == code then return finding end
    end
end

local BT = AI.BehaviorTree
local selector = BT.Selector({
    BT.Condition(function(context) return context.critical == true end, "critical_branch"),
    BT.Action(function() return "fallback_branch" end),
})
local bt_status, bt_value = BT.Tick(selector, { critical = true })
assert(bt_status == BT.SUCCESS and bt_value == "critical_branch", "selector must choose the first successful branch")
local sequence = BT.Sequence({
    BT.Condition(function(context) return context.allowed == true end, "precondition"),
    BT.Action(function(context) return context.value end),
})
bt_status, bt_value = BT.Tick(sequence, { allowed = true, value = "sequence_complete" })
assert(bt_status == BT.SUCCESS and bt_value == "sequence_complete", "sequence must stop only when a child fails")
bt_status = BT.Tick(BT.Action(function() error("synthetic policy fault") end), {})
assert(bt_status == BT.FAILURE, "behavior tree errors must fail closed")

local invalid = AI.Analyze({ schema = "wrong" })
assert(invalid.status == "invalid_input", "invalid schema must fail closed")

local snapshot = {
    schema = "modxpector/world-inventory/v2",
    captured_at = 123,
    truncated = false,
    capabilities = {
        known_mod_list = true,
        loaded_mod_list = true,
        failed_mod_list = true,
    },
    mods = {
        {
            id = "workshop-100",
            name = "Broken Loader",
            load_state = "failed",
            load_error = "attempt to index field 'replica' (a nil value)",
            missing_dependencies = { "workshop-200" },
            disabled_dependencies = { "workshop-300" },
            unverified_dependencies = {},
            metadata_available = true,
        },
        {
            id = "workshop-400",
            name = "Candidate Only",
            load_state = "candidate_not_observed_loaded",
            load_candidate = true,
            loaded_known = true,
            missing_dependencies = {},
            disabled_dependencies = {},
            unverified_dependencies = { "workshop-500" },
            metadata_available = true,
        },
        {
            id = "workshop-600",
            name = "Invalid Flags",
            client_only = true,
            all_clients_required = true,
            load_state = "loaded",
            missing_dependencies = {},
            disabled_dependencies = {},
            unverified_dependencies = {},
            metadata_available = true,
        },
    },
}

local analysis = AI.Analyze(snapshot)
assert(analysis.schema == AI.SCHEMA, "analysis schema missing")
assert(analysis.status == "issues_detected", "confirmed errors should be reported")
assert(analysis.decision == "investigate_critical_load_failures", "behavior tree must prioritize critical load failures")
assert(analysis.summary.critical == 1, "load failure should be critical")
assert(analysis.summary.errors == 2, "missing dependency and invalid flags should be errors")
assert(analysis.summary.warnings == 2, "disabled dependency and unobserved load should be warnings")
assert(analysis.summary.info == 1, "unverified dependency should be informational")

local load_failure = find_code(analysis, "MOD_LOAD_FAILED")
assert(load_failure ~= nil and load_failure.confidence == "confirmed", "load failure evidence must be confirmed")
assert(load_failure.signature == "nil_index", "nil-index signature should be classified")

local not_loaded = find_code(analysis, "MOD_NOT_OBSERVED_LOADED")
assert(not_loaded ~= nil and not_loaded.confidence == "probable", "not-observed-loaded must not be called confirmed")

local plan = AI.BuildPlan(analysis)
assert(plan.schema == AI.PLAN_SCHEMA, "diagnostic plan schema missing")
assert(plan.mode == "read_only", "plan must remain read-only")
assert(plan.total == #analysis.findings, "each finding should map to a unique diagnostic task")
assert(plan.tasks[1].kind == "inspect_load_error", "highest priority diagnostic should be first")
assert(plan.tasks[1].utility > plan.tasks[2].utility, "utility scoring must rank critical evidence above lower-severity findings")
assert(AI.BuildPlan(analysis).tasks[1].id == plan.tasks[1].id, "task identifiers must remain stable across identical analyses")
for _, task in ipairs(plan.tasks) do
    assert(task.execution == "internal_read_only", "diagnostic task must not execute game actions")
    assert(task.requires_virtual_player == false, "diagnostic task must not claim Virtual Player execution")
    assert(task.changes_world == false, "diagnostic task must never mutate world")
end

local community_suite = {
    schema = "modxpector/test-suite/v1",
    id = "community_grass_smoke",
    owner_mod_id = "workshop-100",
    title = "Community mod grass smoke test",
    priority = 80,
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "WALKTO" },
    scenarios = {
        {
            id = "approach_grass",
            title = "Approach a grass tuft",
            steps = {
                { kind = "action", action = "WALKTO", target = { prefab = "grass", radius = 12 }, target_required = true },
                { kind = "assert", assertion = { kind = "player_near_target", target_step = 1, radius = 4 }, verifies_step = 1 },
            },
        },
    },
}
local suite_ok, normalized_suite = AI.ValidateSuite(community_suite)
assert(suite_ok == true and normalized_suite.id == "community_grass_smoke", "valid declarative community suite should be accepted")
local selected = AI.SelectSuites({ community_suite }, {
    schema = "modxpector/world-inventory/v2",
    mods = {
        { id = "workshop-100", enabled = true, loaded = true, loaded_known = true, load_state = "loaded" },
    },
})
assert(#selected == 1 and selected[1].confidence == "confirmed", "suite should be selected only for a loaded owner mod")
local selected_without_prefab = AI.SelectSuites({ community_suite }, {
    schema = "modxpector/world-inventory/v2",
    mods = {
        { id = "workshop-100", enabled = true, loaded = true, loaded_known = true, load_state = "loaded" },
    },
}, {})
assert(#selected_without_prefab == 0, "suite must not be offered when its declared prefab is not registered")
local selected_with_prefab = AI.SelectSuites({ community_suite }, {
    schema = "modxpector/world-inventory/v2",
    mods = {
        { id = "workshop-100", enabled = true, loaded = true, loaded_known = true, load_state = "loaded" },
    },
}, { grass = true })
assert(#selected_with_prefab == 1, "suite should be offered when its owner and prefab are both present")

local builtin_suites = AI.GetBuiltinSuites()
assert(#builtin_suites == 1 and builtin_suites[1].owner_mod_id == "workshop-2323760467",
    "built-in community catalog should include the verified Friendly Skeleton Workshop entry")
local friendly_skeleton_snapshot = {
    schema = "modxpector/world-inventory/v2",
    mods = {
        { id = "workshop-2323760467", enabled = true, loaded = true, loaded_known = true, load_state = "loaded" },
    },
}
local friendly_selected = AI.SelectSuites(builtin_suites, friendly_skeleton_snapshot, { skeletonservant = true })
assert(#friendly_selected == 1 and friendly_selected[1].suite.id == "friendly_skeleton_servant_smoke",
    "Friendly Skeleton smoke suite should require the active mod and registered servant prefab")
local friendly_plan = AI.BuildVirtualPlayerPlan(friendly_selected[1].suite,
    "approach_existing_servant", "friendly_skeleton_run_1")
assert(friendly_plan ~= nil and friendly_plan.steps[1].target.prefab == "skeletonservant",
    "Friendly Skeleton smoke suite should compile to a Virtual Player plan")
local friendly_missing_prefab = AI.SelectSuites(builtin_suites, friendly_skeleton_snapshot, {})
assert(#friendly_missing_prefab == 0,
    "Friendly Skeleton suite must stay hidden if the mod prefab is not registered")
local vp_plan, vp_error = AI.BuildVirtualPlayerPlan(community_suite, "approach_grass", "suite_run_1")
assert(vp_plan ~= nil and vp_error == nil, "valid suite should compile into a Virtual Player plan")
assert(vp_plan.schema == "modxpector/test-plan/v1" and vp_plan.enabled == true)
assert(vp_plan.steps[1].action == "WALKTO" and vp_plan.steps[2].assertion.target_step == 1)
assert(vp_plan.owner_mod_id == "workshop-100" and vp_plan.scenario_id == "approach_grass")

local unsafe_suite = {
    schema = "modxpector/test-suite/v1",
    id = "unsafe_suite",
    owner_mod_id = "workshop-100",
    title = "Unsafe",
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "SPAWN_ITEM" },
    scenarios = {
        { id = "unsafe", title = "Unsafe action", steps = {
            { kind = "action", action = "SPAWN_ITEM", target = { prefab = "grass" }, target_required = true },
        } },
    },
}
suite_ok = AI.ValidateSuite(unsafe_suite)
assert(suite_ok == false, "community suites must not introduce actions outside the safe allowlist")
local no_postcondition = {
    schema = "modxpector/test-suite/v1",
    id = "unverified_suite",
    owner_mod_id = "workshop-100",
    title = "Unverified",
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "WALKTO" },
    scenarios = {
        { id = "unverified", title = "No postcondition", steps = {
            { kind = "action", action = "WALKTO", target = { prefab = "grass" }, target_required = true },
        } },
    },
}
suite_ok = AI.ValidateSuite(no_postcondition)
assert(suite_ok == false, "every action must have an explicit postcondition")
local wrong_target = {
    schema = "modxpector/test-suite/v1",
    id = "wrong_target_suite",
    owner_mod_id = "workshop-100",
    title = "Wrong target",
    allowed_prefabs = { "grass" },
    allowed_recipes = {},
    allowed_actions = { "WALKTO" },
    scenarios = {
        { id = "wrong_target", title = "Wrong target", steps = {
            { kind = "action", action = "WALKTO", target = { prefab = "grass" }, target_required = true },
            { kind = "assert", assertion = { kind = "player_near_target", target_step = 1 }, verifies_step = 2 },
        } },
    },
}
suite_ok = AI.ValidateSuite(wrong_target)
assert(suite_ok == false, "postcondition must reference the same action target")
suite_ok = AI.ValidateSuite({ schema = "modxpector/test-suite/v1", id = "broken", owner_mod_id = "workshop-100", title = "Broken" })
assert(suite_ok == false, "malformed suite data must be rejected without throwing")

local session = AI.NewSession("test-session")
local next_task = AI.NextTask(plan, session)
assert(next_task ~= nil and next_task.id == plan.tasks[1].id, "session should select highest-priority task")
local ok = AI.RecordTaskResult(session, next_task.id, "passed", { source = "test" })
assert(ok == true, "valid task result should be recorded")
assert(AI.NextTask(plan, session).id == plan.tasks[2].id, "completed task should not be repeated")
local bad = AI.RecordTaskResult(session, "bad", "unknown", {})
assert(bad == false, "unknown task status must be rejected")

local incomplete = AI.Analyze({
    schema = "modxpector/world-inventory/v2",
    capabilities = { known_mod_list = true, loaded_mod_list = false, failed_mod_list = false },
    mods = {},
})
assert(incomplete.status == "incomplete_evidence", "missing observability must be explicit")
assert(#incomplete.limitations == 2, "missing capabilities should produce limitations")

print("ModXpector embedded AI tests passed")
