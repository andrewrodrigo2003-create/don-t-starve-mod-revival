-- ModXpector Embedded AI: deterministic, offline-first diagnostic reasoning.
-- Pure Lua 5.1 module. No HTTP, filesystem, model, external runtime, or game globals.
-- This is the first reasoning layer; it creates read-only diagnostic work items.
local M = {}

M.VERSION = "0.1.0"
M.SCHEMA = "modxpector/embedded-ai-analysis/v1"
M.PLAN_SCHEMA = "modxpector/embedded-diagnostic-plan/v1"

local SEVERITY_RANK = {
    critical = 5,
    error = 4,
    warning = 3,
    info = 2,
}

local function is_string(value)
    return type(value) == "string" and value ~= ""
end

local function safe_text(value, limit)
    if not is_string(value) then return nil end
    limit = limit or 1200
    if #value > limit then return value:sub(1, limit) end
    return value
end

local function contains(text, fragment)
    return type(text) == "string" and text:find(fragment, 1, true) ~= nil
end

local function classify_error(message)
    local value = string.lower(tostring(message or ""))
    if contains(value, "attempt to index") and contains(value, "nil") then
        return "nil_index", "A execução tentou acessar um campo de uma referência nil."
    elseif contains(value, "attempt to call") and contains(value, "nil") then
        return "nil_call", "A execução tentou chamar uma função inexistente ou nil."
    elseif contains(value, "syntax error") or contains(value, "unexpected symbol") then
        return "syntax_error", "O carregamento encontrou um erro de sintaxe Lua."
    elseif contains(value, "not declared") or contains(value, "global") then
        return "global_environment", "A mensagem sugere uma referência global ausente ou incompatível."
    elseif contains(value, "loop or previous error loading module") then
        return "module_load_chain", "O carregamento de um módulo falhou ou entrou em ciclo."
    elseif contains(value, "bad argument") then
        return "bad_argument", "Uma chamada recebeu argumento incompatível com a API esperada."
    end
    return "unclassified", "A falha foi observada, mas sua assinatura ainda não corresponde a uma regra conhecida."
end

local function add_finding(findings, finding)
    finding.evidence = type(finding.evidence) == "table" and finding.evidence or {}
    findings[#findings + 1] = finding
end

local function sort_findings(findings)
    table.sort(findings, function(a, b)
        local ar = SEVERITY_RANK[a.severity] or 0
        local br = SEVERITY_RANK[b.severity] or 0
        if ar ~= br then return ar > br end
        if tostring(a.mod_id or "") ~= tostring(b.mod_id or "") then
            return tostring(a.mod_id or "") < tostring(b.mod_id or "")
        end
        if tostring(a.code or "") ~= tostring(b.code or "") then
            return tostring(a.code or "") < tostring(b.code or "")
        end
        return tostring(a.related_id or "") < tostring(b.related_id or "")
    end)
end

local BehaviorTree = {}
BehaviorTree.SUCCESS = "success"
BehaviorTree.FAILURE = "failure"
BehaviorTree.RUNNING = "running"

function BehaviorTree.Condition(predicate, result)
    return function(context)
        local ok, matches = pcall(predicate, context)
        if not ok then return BehaviorTree.FAILURE, nil, tostring(matches) end
        return matches and BehaviorTree.SUCCESS or BehaviorTree.FAILURE, result
    end
end

function BehaviorTree.Action(action)
    return function(context)
        local ok, result = pcall(action, context)
        if not ok then return BehaviorTree.FAILURE, nil, tostring(result) end
        return BehaviorTree.SUCCESS, result
    end
end

function BehaviorTree.Selector(children)
    return function(context)
        for _, child in ipairs(children or {}) do
            local status, result, reason = child(context)
            if status ~= BehaviorTree.FAILURE then return status, result, reason end
        end
        return BehaviorTree.FAILURE, nil, "all selector branches failed"
    end
end

function BehaviorTree.Sequence(children)
    return function(context)
        local last_result
        for _, child in ipairs(children or {}) do
            local status, result, reason = child(context)
            if status ~= BehaviorTree.SUCCESS then return status, result, reason end
            last_result = result
        end
        return BehaviorTree.SUCCESS, last_result
    end
end

function BehaviorTree.Tick(tree, context)
    if type(tree) ~= "function" then
        return BehaviorTree.FAILURE, nil, "invalid behavior tree"
    end
    local ok, status, result, reason = pcall(tree, context)
    if not ok then return BehaviorTree.FAILURE, nil, tostring(status) end
    if status ~= BehaviorTree.SUCCESS and status ~= BehaviorTree.FAILURE
        and status ~= BehaviorTree.RUNNING then
        return BehaviorTree.FAILURE, nil, "behavior tree returned an invalid status"
    end
    return status, result, reason
end

M.BehaviorTree = BehaviorTree

function M.EvaluatePolicy(analysis)
    local summary = type(analysis) == "table" and analysis.summary or {}
    local tree = BehaviorTree.Selector({
        BehaviorTree.Condition(function() return (summary.critical or 0) > 0 end,
            "investigate_critical_load_failures"),
        BehaviorTree.Condition(function() return (summary.errors or 0) > 0 end,
            "resolve_confirmed_configuration_issues"),
        BehaviorTree.Condition(function() return (summary.warnings or 0) > 0 end,
            "confirm_probable_issues"),
        BehaviorTree.Condition(function() return #(analysis.limitations or {}) > 0 end,
            "collect_missing_evidence"),
        BehaviorTree.Action(function() return "baseline_monitoring" end),
    })
    local status, decision, reason = BehaviorTree.Tick(tree, analysis)
    if status ~= BehaviorTree.SUCCESS then return "policy_error", reason end
    return decision
end

local function stable_task_id(kind, mod_id, related_id)
    local function slug(value)
        return tostring(value or "none"):gsub("[^%w_%-]", "_"):sub(1, 56)
    end
    return "diag-" .. slug(kind) .. "-" .. slug(mod_id) .. "-" .. slug(related_id)
end

local SEVERITY_UTILITY = { critical = 100, error = 80, warning = 45, info = 15 }
local CONFIDENCE_UTILITY = { confirmed = 25, probable = 10, unknown = 0 }

local function analyze_mod(mod, findings)
    local id = safe_text(mod.id, 180) or "unknown"
    local name = safe_text(mod.name, 180) or id

    if is_string(mod.load_error) then
        local signature, explanation = classify_error(mod.load_error)
        add_finding(findings, {
            code = "MOD_LOAD_FAILED",
            severity = "critical",
            confidence = "confirmed",
            mod_id = id,
            mod_name = name,
            title = "Falha de carregamento observada",
            detail = explanation,
            signature = signature,
            evidence = { load_state = mod.load_state, error = safe_text(mod.load_error) },
            next_task = "inspect_load_error",
        })
    end

    for _, dependency in ipairs(type(mod.missing_dependencies) == "table" and mod.missing_dependencies or {}) do
        if is_string(dependency) then
            add_finding(findings, {
                code = "DEPENDENCY_MISSING",
                severity = "error",
                confidence = "confirmed",
                mod_id = id,
                mod_name = name,
                related_id = dependency,
                title = "Dependência ausente",
                detail = "O índice de mods informou que a dependência não está instalada.",
                evidence = { dependency = dependency, source = "KnownModIndex.DoesModExistAnyVersion" },
                next_task = "verify_missing_dependency",
            })
        end
    end

    for _, dependency in ipairs(type(mod.disabled_dependencies) == "table" and mod.disabled_dependencies or {}) do
        if is_string(dependency) then
            add_finding(findings, {
                code = "DEPENDENCY_DISABLED",
                severity = "warning",
                confidence = "confirmed",
                mod_id = id,
                mod_name = name,
                related_id = dependency,
                title = "Dependência instalada, mas desativada",
                detail = "O índice reconhece a dependência, mas ela não está habilitada.",
                evidence = { dependency = dependency, source = "KnownModIndex.IsModEnabledAny" },
                next_task = "verify_dependency_enabled",
            })
        end
    end

    if mod.client_only == true and mod.all_clients_required == true then
        add_finding(findings, {
            code = "MOD_FLAGS_CONFLICT",
            severity = "error",
            confidence = "confirmed",
            mod_id = id,
            mod_name = name,
            title = "Metadados de execução incompatíveis",
            detail = "O mod declara client_only_mod e all_clients_require_mod simultaneamente.",
            evidence = { client_only = true, all_clients_required = true },
            next_task = "review_mod_flags",
        })
    end

    if mod.load_state == "candidate_not_observed_loaded"
        or mod.load_state == "enabled_not_observed_loaded" then
        add_finding(findings, {
            code = "MOD_NOT_OBSERVED_LOADED",
            severity = "warning",
            confidence = "probable",
            mod_id = id,
            mod_name = name,
            title = "Carregamento não confirmado",
            detail = "O mod aparece como habilitado/candidato, mas não foi observado na lista de módulos carregados. Isso não prova falha.",
            evidence = {
                load_state = mod.load_state,
                loaded_known = mod.loaded_known == true,
                load_candidate = mod.load_candidate == true,
            },
            next_task = "confirm_load_state",
        })
    end

    for _, dependency in ipairs(type(mod.unverified_dependencies) == "table" and mod.unverified_dependencies or {}) do
        if is_string(dependency) then
            add_finding(findings, {
                code = "DEPENDENCY_UNVERIFIED",
                severity = "info",
                confidence = "unknown",
                mod_id = id,
                mod_name = name,
                related_id = dependency,
                title = "Dependência não verificável",
                detail = "A API disponível não permitiu confirmar se a dependência existe ou está habilitada.",
                evidence = { dependency = dependency },
                next_task = "collect_dependency_evidence",
            })
        end
    end

    if mod.metadata_available == false then
        add_finding(findings, {
            code = "MOD_METADATA_UNAVAILABLE",
            severity = "info",
            confidence = "unknown",
            mod_id = id,
            mod_name = name,
            title = "Metadados indisponíveis",
            detail = "Não foi possível obter os metadados do mod; análises dependentes desses campos foram omitidas.",
            evidence = {},
            next_task = "collect_mod_metadata",
        })
    end
end

local function analyze_community_integrations(snapshot, findings)
    local api_catalog = type(snapshot.community_apis) == "table" and snapshot.community_apis or {}
    local devtools_api = type(api_catalog.dev_tools) == "table" and api_catalog.dev_tools or nil
    if devtools_api == nil then return end

    for _, mod in ipairs(type(snapshot.mods) == "table" and snapshot.mods or {}) do
        if type(mod) == "table" and mod.id == "workshop-2220506640" and mod.enabled == true then
            if devtools_api.available == true and devtools_api.version_observed == true then
                if devtools_api.version > 1 then
                    add_finding(findings, {
                        code = "DEVTOOLS_API_MAJOR_VERSION_UNSUPPORTED",
                        severity = "warning",
                        confidence = "probable",
                        mod_id = mod.id,
                        mod_name = mod.name or "Dev Tools",
                        title = "Versão principal da API Dev Tools não reconhecida",
                        detail = "A API pública do Dev Tools mudou de versão principal; a integração opcional do ModXpector precisa revisar a compatibilidade antes de usá-la.",
                        evidence = {
                            api = "DevToolsAPI",
                            version = devtools_api.version,
                            documented_compatible_range = "<= 1",
                        },
                        next_task = "review_community_api_compatibility",
                    })
                end
            elseif mod.loaded == true or mod.load_state == "loaded" then
                add_finding(findings, {
                    code = "DEVTOOLS_API_NOT_OBSERVED",
                    severity = "info",
                    confidence = "unknown",
                    mod_id = mod.id,
                    mod_name = mod.name or "Dev Tools",
                    title = "API pública do Dev Tools não observada",
                    detail = "O mod está carregado, mas DevToolsAPI:GetAPIVersion não foi observado neste contexto. Isso não prova falha do mod.",
                    evidence = {
                        api = "DevToolsAPI",
                        available = devtools_api.available == true,
                        version_observed = devtools_api.version_observed == true,
                    },
                    next_task = "collect_community_api_evidence",
                })
            end
            break
        end
    end
end

function M.Analyze(snapshot)
    local findings = {}
    if type(snapshot) ~= "table" or snapshot.schema ~= "modxpector/world-inventory/v2" then
        return {
            schema = M.SCHEMA,
            status = "invalid_input",
            findings = {},
            summary = { total = 0, critical = 0, errors = 0, warnings = 0, info = 0 },
            limitations = { "O inventário não corresponde ao schema esperado." },
        }
    end

    local capabilities = type(snapshot.capabilities) == "table" and snapshot.capabilities or {}
    local mods = type(snapshot.mods) == "table" and snapshot.mods or {}
    for _, mod in ipairs(mods) do
        if type(mod) == "table" then analyze_mod(mod, findings) end
    end
    analyze_community_integrations(snapshot, findings)

    local limitations = {}
    if capabilities.known_mod_list ~= true then
        limitations[#limitations + 1] = "A lista de mods conhecidos não está disponível."
    end
    if capabilities.loaded_mod_list ~= true then
        limitations[#limitations + 1] = "O runtime não expôs uma lista observável de mods carregados."
    end
    if capabilities.failed_mod_list ~= true then
        limitations[#limitations + 1] = "A lista de falhas do gerenciador de mods não está disponível."
    end
    if snapshot.truncated == true then
        limitations[#limitations + 1] = "O inventário foi truncado pelo limite de coleta; a análise é parcial."
    end

    sort_findings(findings)
    local summary = { total = #findings, critical = 0, errors = 0, warnings = 0, info = 0 }
    for _, finding in ipairs(findings) do
        if finding.severity == "critical" then summary.critical = summary.critical + 1
        elseif finding.severity == "error" then summary.errors = summary.errors + 1
        elseif finding.severity == "warning" then summary.warnings = summary.warnings + 1
        else summary.info = summary.info + 1 end
    end

    local status = "no_known_issues"
    if summary.critical > 0 or summary.errors > 0 then
        status = "issues_detected"
    elseif summary.warnings > 0 then
        status = "needs_review"
    end
    if #limitations > 0 and status == "no_known_issues" then
        status = "incomplete_evidence"
    end

    local analysis = {
        schema = M.SCHEMA,
        engine_version = M.VERSION,
        status = status,
        captured_at = tonumber(snapshot.captured_at) or 0,
        findings = findings,
        summary = summary,
        limitations = limitations,
        statement = status == "no_known_issues"
            and "Nenhum problema conhecido foi identificado nos dados disponíveis; isso não comprova compatibilidade."
            or "A análise encontrou achados ou limitações que exigem investigação.",
    }
    analysis.decision = M.EvaluatePolicy(analysis)
    return analysis
end

local TASK_PRIORITY = {
    inspect_load_error = 100,
    verify_missing_dependency = 90,
    review_mod_flags = 85,
    verify_dependency_enabled = 75,
    confirm_load_state = 50,
    collect_dependency_evidence = 25,
    collect_mod_metadata = 20,
    review_community_api_compatibility = 35,
    collect_community_api_evidence = 15,
}

function M.BuildPlan(analysis)
    local tasks, seen = {}, {}
    if type(analysis) ~= "table" or analysis.schema ~= M.SCHEMA then
        return { schema = M.PLAN_SCHEMA, mode = "read_only", tasks = {}, error = "invalid_analysis" }
    end

    for _, finding in ipairs(analysis.findings or {}) do
        local kind = finding.next_task
        local key = tostring(kind) .. "|" .. tostring(finding.mod_id) .. "|" .. tostring(finding.related_id or "")
        if type(kind) == "string" and not seen[key] then
            seen[key] = true
            local utility = (TASK_PRIORITY[kind] or 0)
                + (SEVERITY_UTILITY[finding.severity] or 0)
                + (CONFIDENCE_UTILITY[finding.confidence] or 0)
            tasks[#tasks + 1] = {
                id = stable_task_id(kind, finding.mod_id, finding.related_id),
                kind = kind,
                priority = utility,
                utility = utility,
                mod_id = finding.mod_id,
                related_id = finding.related_id,
                finding_code = finding.code,
                confidence = finding.confidence,
                evidence = finding.evidence,
                execution = "internal_read_only",
                requires_virtual_player = false,
                changes_world = false,
            }
        end
    end

    table.sort(tasks, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        if tostring(a.mod_id) ~= tostring(b.mod_id) then return tostring(a.mod_id) < tostring(b.mod_id) end
        return tostring(a.kind) < tostring(b.kind)
    end)
    for index, task in ipairs(tasks) do task.order = index end

    return {
        schema = M.PLAN_SCHEMA,
        engine_version = M.VERSION,
        mode = "read_only",
        generated_from = analysis.schema,
        decision = analysis.decision or M.EvaluatePolicy(analysis),
        tasks = tasks,
        total = #tasks,
        statement = "Plano diagnóstico interno; não executa ações no mundo nem substitui um plano do Virtual Player.",
    }
end

function M.NewSession(session_id)
    return {
        schema = "modxpector/embedded-ai-session/v1",
        id = safe_text(session_id, 96) or "session",
        completed = {},
        results = {},
    }
end

function M.RecordTaskResult(session, task_id, status, evidence)
    if type(session) ~= "table" or session.schema ~= "modxpector/embedded-ai-session/v1"
        or not is_string(task_id) then
        return false, "invalid_session_or_task"
    end
    if status ~= "passed" and status ~= "failed" and status ~= "inconclusive" then
        return false, "invalid_task_status"
    end
    session.completed[task_id] = status
    if #session.results >= 200 then table.remove(session.results, 1) end
    session.results[#session.results + 1] = {
        task_id = task_id,
        status = status,
        evidence = type(evidence) == "table" and evidence or {},
    }
    return true
end

function M.NextTask(plan, session)
    if type(plan) ~= "table" or plan.schema ~= M.PLAN_SCHEMA
        or type(session) ~= "table" or session.schema ~= "modxpector/embedded-ai-session/v1" then
        return nil
    end
    for _, task in ipairs(plan.tasks or {}) do
        if session.completed[task.id] == nil then return task end
    end
    return nil
end

local BUILTIN_COMMUNITY_SUITES = {
    {
        schema = "modxpector/test-suite/v1",
        id = "friendly_skeleton_servant_smoke",
        owner_mod_id = "workshop-2323760467",
        title = "Friendly Skeleton - AI: aproximação ao Servant",
        priority = 60,
        allowed_prefabs = { "skeletonservant" },
        allowed_recipes = {},
        allowed_actions = { "WALKTO" },
        scenarios = {
            {
                id = "approach_existing_servant",
                title = "Aproximar-se de um Skeleton Servant existente",
                steps = {
                    {
                        kind = "action",
                        action = "WALKTO",
                        target = { prefab = "skeletonservant", radius = 12 },
                        target_required = true,
                    },
                    {
                        kind = "assert",
                        assertion = { kind = "player_near_target", target_step = 1, radius = 4 },
                        verifies_step = 1,
                    },
                },
            },
        },
    },
}

function M.GetBuiltinSuites()
    -- Return fresh data so callers cannot mutate the embedded catalog.
    local suites = {}
    for index, suite in ipairs(BUILTIN_COMMUNITY_SUITES) do
        local valid, normalized = M.ValidateSuite(suite)
        if valid then suites[index] = normalized end
    end
    return suites
end

local SUITE_ACTION_ALLOWLIST = { WALKTO = true }
local SUITE_ASSERTION_ALLOWLIST = {
    player_health_gte = true,
    player_hunger_gte = true,
    player_sanity_gte = true,
    player_has_item = true,
    player_has_item_count_gte = true,
    player_near_target = true,
    target_exists = true,
    target_has_tag = true,
}

local function safe_identifier(value)
    return type(value) == "string" and #value >= 1 and #value <= 64
        and value:match("^[%w_%-]+$") ~= nil
end

local function list_to_set(values, maximum)
    if type(values) ~= "table" or #values > maximum then return nil end
    local set, normalized = {}, {}
    for _, value in ipairs(values) do
        if not safe_identifier(value) or set[value] then return nil end
        set[value] = true
        normalized[#normalized + 1] = value
    end
    return set, normalized
end

local function finite_in_range(value, minimum, maximum)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value >= minimum and value <= maximum
end

local function copy_target(target, prefab_set)
    if type(target) ~= "table" or not safe_identifier(target.prefab)
        or prefab_set[target.prefab] ~= true then return nil end
    if target.radius ~= nil and not finite_in_range(target.radius, 1, 40) then return nil end
    if target.tag ~= nil and not safe_identifier(target.tag) then return nil end
    local result = { prefab = target.prefab }
    if target.radius ~= nil then result.radius = target.radius end
    if target.tag ~= nil then result.tag = target.tag end
    return result
end

local function copy_assertion(assertion, index, previous_actions, prefab_set, recipe_set)
    if type(assertion) ~= "table" or SUITE_ASSERTION_ALLOWLIST[assertion.kind] ~= true then return nil end
    local result = { kind = assertion.kind }
    if assertion.expected ~= nil then
        if type(assertion.expected) ~= "boolean" then return nil end
        result.expected = assertion.expected
    end

    local kind = assertion.kind
    if kind == "player_health_gte" or kind == "player_hunger_gte" or kind == "player_sanity_gte"
        or kind == "target_health_lte" then
        if not finite_in_range(assertion.value, 0, 100000) then return nil end
        result.value = assertion.value
    elseif kind == "player_near_target" or kind == "target_exists" or kind == "target_has_tag" then
        local target_step = assertion.target_step
        if not finite_in_range(target_step, 1, index - 1)
            or target_step ~= math.floor(target_step) or previous_actions[target_step] ~= true then return nil end
        result.target_step = target_step
        if kind == "player_near_target" then
            if assertion.radius ~= nil and not finite_in_range(assertion.radius, 0, 100) then return nil end
            if assertion.radius ~= nil then result.radius = assertion.radius end
        elseif kind == "target_has_tag" then
            if not safe_identifier(assertion.tag) then return nil end
            result.tag = assertion.tag
        end
    else
        return nil
    end
    return result
end

function M.ValidateSuite(suite)
    if type(suite) ~= "table" or suite.schema ~= "modxpector/test-suite/v1" then
        return false, "unsupported_suite_schema"
    end
    if not safe_identifier(suite.id) or not safe_identifier(suite.owner_mod_id)
        or type(suite.title) ~= "string" or #suite.title < 1 or #suite.title > 160 then
        return false, "invalid_suite_identity"
    end
    local prefab_set, prefabs = list_to_set(suite.allowed_prefabs or {}, 40)
    local recipe_set, recipes = list_to_set(suite.allowed_recipes or {}, 40)
    local action_set, actions = list_to_set(suite.allowed_actions or {}, 10)
    if prefab_set == nil or recipe_set == nil or action_set == nil then
        return false, "invalid_suite_allowlist"
    end
    for _, action in ipairs(actions) do
        if SUITE_ACTION_ALLOWLIST[action] ~= true then return false, "action_not_allowed:" .. action end
    end
    if type(suite.scenarios) ~= "table" or #suite.scenarios < 1 or #suite.scenarios > 20 then
        return false, "invalid_scenario_list"
    end

    local normalized = {
        schema = "modxpector/test-suite/v1",
        id = suite.id,
        owner_mod_id = suite.owner_mod_id,
        title = suite.title,
        priority = finite_in_range(suite.priority or 0, 0, 100) and (suite.priority or 0) or 0,
        allowed_prefabs = prefabs,
        allowed_recipes = recipes,
        allowed_actions = actions,
        scenarios = {},
    }
    local seen_scenarios = {}
    for _, scenario in ipairs(suite.scenarios) do
        if type(scenario) ~= "table" or not safe_identifier(scenario.id)
            or seen_scenarios[scenario.id] or type(scenario.title) ~= "string"
            or #scenario.title < 1 or #scenario.title > 160
            or type(scenario.steps) ~= "table" or #scenario.steps < 1 or #scenario.steps > 20 then
            return false, "invalid_scenario"
        end
        seen_scenarios[scenario.id] = true
        local previous_actions, steps, verified = {}, {}, {}
        for index, step in ipairs(scenario.steps) do
            if type(step) ~= "table" then return false, "invalid_step:" .. tostring(index) end
            if step.kind == "action" then
                if step.action ~= "WALKTO" or action_set.WALKTO ~= true
                    or step.target_required ~= true then return false, "unsafe_action_step:" .. tostring(index) end
                local target = copy_target(step.target, prefab_set)
                if target == nil then return false, "invalid_action_target:" .. tostring(index) end
                local normalized_step = {
                    kind = "action",
                    action = "WALKTO",
                    target = target,
                    target_required = true,
                }
                if step.timeout ~= nil then
                    if not finite_in_range(step.timeout, 1, 120) then return false, "invalid_step_timeout" end
                    normalized_step.timeout = step.timeout
                end
                steps[#steps + 1] = normalized_step
                previous_actions[index] = true
            elseif step.kind == "assert" then
                local assertion = copy_assertion(step.assertion, index, previous_actions, prefab_set, recipe_set)
                if assertion == nil then return false, "invalid_assertion_step:" .. tostring(index) end
                local verifies_step = step.verifies_step
                if not finite_in_range(verifies_step, 1, index - 1)
                    or verifies_step ~= math.floor(verifies_step) or previous_actions[verifies_step] ~= true then
                    return false, "assertion_must_verify_prior_action:" .. tostring(index)
                end
                if assertion.target_step ~= nil and assertion.target_step ~= verifies_step then
                    return false, "assertion_target_must_match_verified_action:" .. tostring(index)
                end
                verified[verifies_step] = true
                steps[#steps + 1] = {
                    kind = "assert",
                    assertion = assertion,
                    verifies_step = verifies_step,
                }
            else
                return false, "step_kind_not_allowed:" .. tostring(index)
            end
        end
        for action_index in pairs(previous_actions) do
            if not verified[action_index] then return false, "action_without_postcondition:" .. tostring(action_index) end
        end
        normalized.scenarios[#normalized.scenarios + 1] = {
            id = scenario.id,
            title = scenario.title,
            steps = steps,
        }
    end
    return true, normalized
end

function M.SelectSuites(suites, snapshot, available_prefabs)
    local active = {}
    local mods = type(snapshot) == "table" and type(snapshot.mods) == "table" and snapshot.mods or {}
    for _, mod in ipairs(mods) do
        if type(mod) == "table" and mod.enabled == true
            and not (mod.loaded_known == true and mod.loaded ~= true)
            and mod.load_state ~= "failed" then
            active[mod.id] = mod
        end
    end
    local selected = {}
    for _, candidate in ipairs(type(suites) == "table" and suites or {}) do
        local valid, suite = M.ValidateSuite(candidate)
        local prefabs_available = valid and type(available_prefabs) == "table"
        if prefabs_available then
            for _, prefab in ipairs(suite.allowed_prefabs) do
                if available_prefabs[prefab] == nil then
                    prefabs_available = false
                    break
                end
            end
        end
        if valid and prefabs_available and active[suite.owner_mod_id] ~= nil then
            selected[#selected + 1] = {
                suite = suite,
                mod = active[suite.owner_mod_id],
                confidence = active[suite.owner_mod_id].loaded == true and "confirmed" or "probable",
            }
        end
    end
    table.sort(selected, function(a, b)
        if a.suite.priority ~= b.suite.priority then return a.suite.priority > b.suite.priority end
        return a.suite.id < b.suite.id
    end)
    return selected
end

function M.BuildVirtualPlayerPlan(suite, scenario_id, run_id)
    local valid, normalized = M.ValidateSuite(suite)
    if not valid then return nil, normalized end
    if not safe_identifier(run_id) then return nil, "invalid_run_id" end
    local scenario
    for _, candidate in ipairs(normalized.scenarios) do
        if candidate.id == scenario_id then scenario = candidate; break end
    end
    if scenario == nil then return nil, "scenario_not_found" end
    return {
        schema = "modxpector/test-plan/v1",
        enabled = true,
        run_id = run_id,
        allowed_prefabs = normalized.allowed_prefabs,
        allowed_recipes = normalized.allowed_recipes,
        allowed_actions = normalized.allowed_actions,
        steps = scenario.steps,
        suite_id = normalized.id,
        owner_mod_id = normalized.owner_mod_id,
        scenario_id = scenario.id,
    }
end

return M
