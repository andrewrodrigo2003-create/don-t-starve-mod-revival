local ROOT = os.getenv("DST_RUNTIME_ROOT") or "."
local AI = dofile(ROOT .. "/dst-mods/modxpector/scripts/modxpector/embedded_ai.lua")

local function find_code(analysis, code)
    for _, finding in ipairs(analysis.findings or {}) do
        if finding.code == code then return finding end
    end
end

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
for _, task in ipairs(plan.tasks) do
    assert(task.execution == "internal_read_only", "diagnostic task must not execute game actions")
    assert(task.requires_virtual_player == false, "diagnostic task must not claim Virtual Player execution")
    assert(task.changes_world == false, "diagnostic task must never mutate world")
end

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
