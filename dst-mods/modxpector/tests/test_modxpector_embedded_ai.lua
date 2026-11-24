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

local memory_context = { tree_memory = {} }
local memory_counts = { precondition = 0, running_action = 0, tail = 0 }
local memory_sequence = BT.MemorySequence({
    BT.Action(function()
        memory_counts.precondition = memory_counts.precondition + 1
        return "precondition_ok"
    end),
    BT.AsyncAction(function()
        memory_counts.running_action = memory_counts.running_action + 1
        if memory_counts.running_action == 1 then return BT.RUNNING, "waiting" end
        return BT.SUCCESS, "action_done"
    end),
    BT.Action(function()
        memory_counts.tail = memory_counts.tail + 1
        return "sequence_done"
    end),
}, "test_sequence")
bt_status = BT.Tick(memory_sequence, memory_context)
assert(bt_status == BT.RUNNING and memory_counts.precondition == 1 and memory_counts.tail == 0,
    "memory sequence should retain its running child without advancing")
bt_status, bt_value = BT.Tick(memory_sequence, memory_context)
assert(bt_status == BT.SUCCESS and bt_value == "sequence_done",
    "memory sequence should resume and finish after its running child succeeds")
assert(memory_counts.precondition == 1 and memory_counts.running_action == 2 and memory_counts.tail == 1,
    "memory sequence must not restart completed children")
assert(memory_context.tree_memory.test_sequence == nil,
    "memory sequence should clear its cursor after completion")

local selector_counts = { first = 0, second = 0, third = 0 }
local memory_selector = BT.MemorySelector({
    BT.Condition(function()
        selector_counts.first = selector_counts.first + 1
        return false
    end, "first"),
    BT.AsyncAction(function()
        selector_counts.second = selector_counts.second + 1
        if selector_counts.second == 1 then return BT.RUNNING, "pending" end
        return BT.SUCCESS, "second_done"
    end),
    BT.Action(function()
        selector_counts.third = selector_counts.third + 1
        return "third"
    end),
}, "test_selector")
bt_status = BT.Tick(memory_selector, memory_context)
assert(bt_status == BT.RUNNING and selector_counts.first == 1 and selector_counts.second == 1,
    "memory selector should preserve the branch that is still running")
bt_status, bt_value = BT.Tick(memory_selector, memory_context)
assert(bt_status == BT.SUCCESS and bt_value == "second_done",
    "memory selector should resume the running branch")
assert(selector_counts.first == 1 and selector_counts.second == 2 and selector_counts.third == 0,
    "memory selector must not reevaluate earlier failed branches")
assert(BT.ResetMemory(memory_context, "test_selector") == true,
    "tree memory should support explicit reset")
assert(BT.ResetMemory(memory_context) == true,
    "tree memory should support complete reset")
local invalid_memory_tree = BT.MemorySequence({}, nil)
bt_status = BT.Tick(invalid_memory_tree, {})
assert(bt_status == BT.FAILURE, "memory composites must fail closed without a unique key")
local corrupt_memory_context = { tree_memory = { corrupt = "not-an-index" } }
local recovered_memory_tree = BT.MemorySequence({
    BT.Action(function() return "recovered" end),
}, "corrupt")
bt_status, bt_value = BT.Tick(recovered_memory_tree, corrupt_memory_context)
assert(bt_status == BT.SUCCESS and bt_value == "recovered",
    "memory composites must reset invalid cursors safely")

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
            dependencies_known = true,
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
            dependencies_known = true,
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
            dependencies_known = true,
            missing_dependencies = {},
            disabled_dependencies = {},
            unverified_dependencies = {},
            metadata_available = true,
        },
    },
}

local devtools_api_snapshot = {
    schema = "modxpector/world-inventory/v2",
    capabilities = { known_mod_list = true, loaded_mod_list = true, failed_mod_list = true },
    mods = {
        { id = "workshop-2220506640", name = "Dev Tools", enabled = true, loaded = true,
            loaded_known = true, load_state = "loaded", missing_dependencies = {},
            disabled_dependencies = {}, unverified_dependencies = {}, metadata_available = true },
    },
    community_apis = { dev_tools = { available = true, version = 0.1, version_observed = true } },
}
local devtools_analysis = AI.Analyze(devtools_api_snapshot)
assert(find_code(devtools_analysis, "DEVTOOLS_API_NOT_OBSERVED") == nil,
    "a supported DevToolsAPI version should not produce an unavailable finding")
assert(find_code(devtools_analysis, "DEVTOOLS_API_MAJOR_VERSION_UNSUPPORTED") == nil,
    "the documented DevToolsAPI 0.x version should remain compatible")

devtools_api_snapshot.community_apis.dev_tools.version = 2
devtools_analysis = AI.Analyze(devtools_api_snapshot)
local devtools_version_finding = find_code(devtools_analysis, "DEVTOOLS_API_MAJOR_VERSION_UNSUPPORTED")
local devtools_plan = AI.BuildPlan(devtools_analysis)
local devtools_session = AI.NewSession("devtools-task-test")
local devtools_execution = AI.RunReadOnlyPlan(devtools_plan, devtools_session, devtools_api_snapshot, 20)
assert(devtools_execution.executed == 1 and devtools_execution.results[1].status == "passed",
    "Dev Tools major API change task should record the observed version")
assert(devtools_version_finding ~= nil and devtools_version_finding.confidence == "probable",
    "a major DevToolsAPI version change should request compatibility review, not assert failure")

devtools_api_snapshot.community_apis.dev_tools.available = false
devtools_api_snapshot.community_apis.dev_tools.version_observed = false
devtools_analysis = AI.Analyze(devtools_api_snapshot)
local devtools_missing_finding = find_code(devtools_analysis, "DEVTOOLS_API_NOT_OBSERVED")
assert(devtools_missing_finding ~= nil and devtools_missing_finding.confidence == "unknown",
    "a missing optional API should remain unknown, not be classified as a confirmed mod failure")

local analysis = AI.Analyze(snapshot)
assert(analysis.schema == AI.SCHEMA, "analysis schema missing")
assert(analysis.registry.runtime_components.enabled == false
    and analysis.registry.runtime_components.available == false,
    "analysis should report the opt-in runtime component observer as disabled when no data is supplied")

local observed_snapshot = {
    schema = "modxpector/world-inventory/v2",
    capabilities = { known_mod_list = true, loaded_mod_list = true, failed_mod_list = true },
    mods = {},
    runtime_components = {
        enabled = true, available = true, hooks_registered = 12,
        hook_failures = 0, callback_errors = 0, dropped = 0,
        components = {
            { name = "health", count = 10 },
            { name = "inventory", count = 2 },
        },
        events = {
            { component = "health", prefab = "skeletonservant", time = 42 },
            { component = "inventory", prefab = "skeletonservant", time = 43 },
            { component = "combat", prefab = "unknown", time = 44 },
        },
    },
}
local observed_analysis = AI.Analyze(observed_snapshot)
local observed_registry = observed_analysis.registry.runtime_components
assert(observed_registry.enabled and observed_registry.available and observed_registry.hooks_registered == 12)
assert(observed_registry.event_count == 3 and observed_registry.dropped == 0)
assert(observed_registry.component_counts[1].name == "health"
    and observed_registry.component_counts[1].count == 10)
assert(observed_registry.observed_prefabs[1] == "skeletonservant"
    and #observed_registry.observed_prefabs == 1)
assert(#observed_registry.event_sample == 3
    and observed_registry.event_sample[1].component == "health",
    "AI analysis should expose a bounded, sanitized component/prefab evidence sample")
observed_snapshot.runtime_components.dropped = 5
observed_analysis = AI.Analyze(observed_snapshot)
local dropped_limitation = false
for _, limitation in ipairs(observed_analysis.limitations) do
    if limitation:find("buffer", 1, true) then dropped_limitation = true end
end
assert(dropped_limitation, "dropped runtime component events must be reported as an evidence limitation")

local community_event_snapshot = {
    schema = "modxpector/world-inventory/v2",
    capabilities = { known_mod_list = true, loaded_mod_list = true, failed_mod_list = true },
    mods = {
        { id = "workshop-12345", name = "Community Agent Mod", enabled = true, loaded = true },
    },
    community_events = {
        enabled = true, available = true, event_count = 2, dropped = 0,
        events = {
            { id = 1, mod_id = "workshop-12345", source_verified = true,
                kind = "runtime_error", severity = "error", message = "attempt to index nil",
                stack = "scripts/community.lua:10", prefab = "skeletonservant",
                component = "combat", repeat_count = 2 },
            { id = 2, mod_id = "workshop-12345", kind = "capability_observed",
                severity = "info", message = "new prefab registered", repeat_count = 1 },
        },
    },
}
local community_event_analysis = AI.Analyze(community_event_snapshot)
local community_finding = find_code(community_event_analysis, "COMMUNITY_EVENT_UNVERIFIED")
assert(community_finding ~= nil and community_finding.severity == "warning"
    and community_finding.confidence == "unknown",
    "community runtime errors must be shown as warnings with unknown confidence")
assert(community_finding.evidence.source_verified == false
    and community_finding.evidence.claimed_mod_active == true
    and community_finding.evidence.repeat_count == 2,
    "claimed mod identity must remain unverified even if the mod is active")
assert(community_event_analysis.community_events.unverified == true
    and community_event_analysis.community_events.event_count == 2
    and #community_event_analysis.community_events.event_sample == 2,
    "analysis must expose a bounded community event summary")
community_event_snapshot.community_events.dropped = 3
community_event_analysis = AI.Analyze(community_event_snapshot)
local event_drop_limitation = false
for _, limitation in ipairs(community_event_analysis.limitations) do
    if limitation:find("eventos comunitários", 1, true) then event_drop_limitation = true end
end
assert(event_drop_limitation, "dropped community events must reduce evidence completeness")
local disabled_event_analysis = AI.Analyze({
    schema = "modxpector/world-inventory/v2",
    capabilities = { known_mod_list = true, loaded_mod_list = true, failed_mod_list = true },
    mods = {},
    community_events = {
        enabled = false, available = false,
        events = {
            { id = 99, mod_id = "workshop-99", kind = "runtime_error",
                severity = "error", message = "must not be ingested" },
        },
    },
})
assert(find_code(disabled_event_analysis, "COMMUNITY_EVENT_UNVERIFIED") == nil
    and disabled_event_analysis.community_events.event_count == 0,
    "AI must ignore community events when opt-in ingestion is disabled")
assert(analysis.registry.prefabs.available == false and analysis.registry.prefabs.count == nil,
    "analysis should report registry evidence as unavailable when the snapshot omitted it")
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
local diagnostic_session = AI.NewSession("diagnostic-worker-test")
local task_execution = AI.RunReadOnlyPlan(plan, diagnostic_session, snapshot, 200)
assert(task_execution.executed == plan.total and task_execution.complete == true,
    "read-only worker should execute every supported diagnostic task")
assert(task_execution.next_task == nil and #diagnostic_session.results == plan.total,
    "read-only worker should record each task and expose no remaining task")
local task_outcomes = {}
for _, result in ipairs(task_execution.results) do
    task_outcomes[result.kind] = result
end
assert(task_outcomes.inspect_load_error.status == "passed"
    and task_outcomes.inspect_load_error.evidence.diagnostic_outcome == "load_error_confirmed",
    "load error investigation should record confirmed read-only evidence")
assert(task_outcomes.verify_missing_dependency.status == "passed",
    "missing dependency investigation should confirm the inventory evidence")
assert(task_outcomes.verify_dependency_enabled.status == "passed",
    "disabled dependency investigation should confirm the inventory evidence")
assert(task_outcomes.review_mod_flags.status == "passed",
    "mod flag investigation should confirm the conflicting metadata")
assert(task_outcomes.confirm_load_state.status == "passed",
    "load state investigation should confirm an unobserved candidate")
assert(task_outcomes.collect_dependency_evidence.status == "inconclusive",
    "unverifiable dependencies must remain inconclusive")
local repeated_execution = AI.RunReadOnlyPlan(plan, diagnostic_session, snapshot, 200)
assert(repeated_execution.executed == 0 and repeated_execution.complete == true,
    "completed diagnostic tasks must not be repeated in the same session")
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
}, { grass = true })
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
assert(#incomplete.limitations >= 3, "missing capabilities and disabled optional observers should produce limitations")
local runtime_observer_limitation = false
for _, limitation in ipairs(incomplete.limitations) do
    if limitation:find("observação opt-in", 1, true) then runtime_observer_limitation = true end
end
assert(runtime_observer_limitation, "disabled runtime component observation must be an explicit limitation")

print("ModXpector embedded AI tests passed")
