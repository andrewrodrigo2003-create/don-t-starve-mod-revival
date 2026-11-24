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

return M
