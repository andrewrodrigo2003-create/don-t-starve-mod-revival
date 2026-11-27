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

local function valid_tree_status(status)
    return status == BehaviorTree.SUCCESS or status == BehaviorTree.FAILURE
        or status == BehaviorTree.RUNNING
end

function BehaviorTree.AsyncAction(action)
    return function(context)
        if type(action) ~= "function" then
            return BehaviorTree.FAILURE, nil, "invalid async action"
        end
        local ok, status, result, reason = pcall(action, context)
        if not ok then return BehaviorTree.FAILURE, nil, tostring(status) end
        if not valid_tree_status(status) then
            return BehaviorTree.FAILURE, nil, "async action returned an invalid status"
        end
        return status, result, reason
    end
end

local function get_tree_memory(context, key)
    if type(context) ~= "table" or type(key) ~= "string" or key == "" then return nil end
    if type(context.tree_memory) ~= "table" then context.tree_memory = {} end
    return context.tree_memory
end

function BehaviorTree.ResetMemory(context, key)
    if type(context) ~= "table" or type(context.tree_memory) ~= "table" then return false end
    if key == nil then
        context.tree_memory = {}
        return true
    end
    if type(key) ~= "string" or key == "" then return false end
    context.tree_memory[key] = nil
    return true
end

function BehaviorTree.MemorySelector(children, memory_key)
    return function(context)
        local memory = get_tree_memory(context, memory_key)
        if memory == nil then
            return BehaviorTree.FAILURE, nil, "memory selector requires a context and unique key"
        end
        if type(children) ~= "table" then
            memory[memory_key] = nil
            return BehaviorTree.FAILURE, nil, "memory selector children must be a table"
        end
        local index = memory[memory_key]
        if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #children then
            index = 1
        end
        while index <= #children do
            local child = children[index]
            if type(child) ~= "function" then
                memory[memory_key] = nil
                return BehaviorTree.FAILURE, nil, "invalid selector child"
            end
            local status, result, reason = child(context)
            if not valid_tree_status(status) then
                memory[memory_key] = nil
                return BehaviorTree.FAILURE, nil, "selector child returned an invalid status"
            end
            if status == BehaviorTree.SUCCESS then
                memory[memory_key] = nil
                return status, result, reason
            elseif status == BehaviorTree.RUNNING then
                memory[memory_key] = index
                return status, result, reason
            end
            index = index + 1
        end
        memory[memory_key] = nil
        return BehaviorTree.FAILURE, nil, "all memory selector branches failed"
    end
end

function BehaviorTree.MemorySequence(children, memory_key)
    return function(context)
        local memory = get_tree_memory(context, memory_key)
        if memory == nil then
            return BehaviorTree.FAILURE, nil, "memory sequence requires a context and unique key"
        end
        if type(children) ~= "table" then
            memory[memory_key] = nil
            return BehaviorTree.FAILURE, nil, "memory sequence children must be a table"
        end
        local index = memory[memory_key]
        if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #children then
            index = 1
        end
        local last_result
        while index <= #children do
            local child = children[index]
            if type(child) ~= "function" then
                memory[memory_key] = nil
                return BehaviorTree.FAILURE, nil, "invalid sequence child"
            end
            local status, result, reason = child(context)
            if not valid_tree_status(status) then
                memory[memory_key] = nil
                return BehaviorTree.FAILURE, nil, "sequence child returned an invalid status"
            end
            if status == BehaviorTree.FAILURE then
                memory[memory_key] = nil
                return status, result, reason
            elseif status == BehaviorTree.RUNNING then
                memory[memory_key] = index
                return status, result, reason
            end
            last_result = result
            index = index + 1
        end
        memory[memory_key] = nil
        return BehaviorTree.SUCCESS, last_result
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
    local community_events = type(snapshot.community_events) == "table" and snapshot.community_events or {}
    local community_event_list = {}
    if community_events.enabled == true and community_events.available == true
        and type(community_events.events) == "table" then
        community_event_list = community_events.events
    end
    for index, event in ipairs(community_event_list) do
        if index > 128 then break end
        if type(event) == "table"
            and (event.kind == "runtime_error" or event.kind == "compatibility_warning") then
            local source_mod_id = safe_text(event.mod_id, 80)
            local event_message = safe_text(event.message, 500) or "Um mod enviou um evento sem mensagem legível."
            local event_stack = safe_text(event.stack, 1200)
            local signature, interpretation = classify_error(event_message .. " " .. (event_stack or ""))
            local source_mod_name
            local source_mod_active = false
            for _, candidate in ipairs(type(snapshot.mods) == "table" and snapshot.mods or {}) do
                if type(candidate) == "table" and candidate.id == source_mod_id then
                    source_mod_name = safe_text(candidate.name, 120)
                    source_mod_active = candidate.enabled == true
                    break
                end
            end
            add_finding(findings, {
                code = "COMMUNITY_EVENT_UNVERIFIED",
                severity = "warning",
                confidence = "unknown",
                mod_id = source_mod_id,
                mod_name = source_mod_name or source_mod_id or "Mod comunitário",
                title = "Evento comunitário relatado, origem não verificada",
                detail = signature ~= "unclassified" and interpretation or event_message,
                evidence = {
                    event_id = tonumber(event.id),
                    event_kind = event.kind,
                    signature = signature,
                    interpretation = interpretation,
                    source_claimed = source_mod_id,
                    source_verified = false,
                    claimed_mod_active = source_mod_active,
                    repeat_count = tonumber(event.repeat_count) or 1,
                    prefab = safe_text(event.prefab, 80),
                    component = safe_text(event.component, 40),
                    stack_excerpt = event_stack,
                },
            })
        end
    end

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
    local runtime_components = type(snapshot.runtime_components) == "table" and snapshot.runtime_components or {}
    if runtime_components.enabled ~= true then
        limitations[#limitations + 1] = "A observação opt-in de componentes em runtime está desativada."
    elseif runtime_components.available ~= true then
        limitations[#limitations + 1] = "A observação de componentes foi solicitada, mas os hooks não ficaram disponíveis."
    end
    if (tonumber(runtime_components.hook_failures) or 0) > 0 then
        limitations[#limitations + 1] = "Alguns hooks de observação de componentes não puderam ser registrados."
    end
    if (tonumber(runtime_components.callback_errors) or 0) > 0 then
        limitations[#limitations + 1] = "O observador de componentes encontrou erros ao registrar eventos."
    end
    local community_events = type(snapshot.community_events) == "table" and snapshot.community_events or {}
    if community_events.enabled == true and community_events.available ~= true then
        limitations[#limitations + 1] = "A ingestão de eventos comunitários foi ativada, mas não ficou disponível."
    end
    if (tonumber(community_events.dropped) or 0) > 0 then
        limitations[#limitations + 1] = "O buffer de eventos comunitários descartou relatos por atingir limites."
    end
    if (tonumber(runtime_components.dropped) or 0) > 0 then
        limitations[#limitations + 1] = "O buffer de observação de componentes descartou eventos por atingir o limite."
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

    local runtime_component_counts = {}
    local runtime_observed_events = {}
    local runtime_observed_prefabs = {}
    local runtime_prefab_seen = {}
    for _, item in ipairs(type(runtime_components.components) == "table" and runtime_components.components or {}) do
        if #runtime_component_counts >= 12 then break end
        if type(item) == "table" and is_string(item.name)
            and type(item.count) == "number" and item.count >= 0 then
            runtime_component_counts[#runtime_component_counts + 1] = {
                name = safe_text(item.name, 40),
                count = item.count,
            }
        end
    end
    for _, event in ipairs(type(runtime_components.events) == "table" and runtime_components.events or {}) do
        if #runtime_observed_events >= 64 then break end
        if type(event) == "table" then
            local component_name = safe_text(event.component, 40)
            local prefab_name = safe_text(event.prefab, 80)
            if component_name ~= nil and prefab_name ~= nil then
                runtime_observed_events[#runtime_observed_events + 1] = {
                    component = component_name,
                    prefab = prefab_name,
                    time = type(event.time) == "number" and event.time or 0,
                }
                if prefab_name ~= "unknown" and not runtime_prefab_seen[prefab_name] then
                    runtime_prefab_seen[prefab_name] = true
                    runtime_observed_prefabs[#runtime_observed_prefabs + 1] = prefab_name
                end
            end
        end
    end
    table.sort(runtime_observed_prefabs)
    while #runtime_observed_prefabs > 64 do table.remove(runtime_observed_prefabs) end

    local registry = type(snapshot.registry) == "table" and snapshot.registry or {}
    local analysis = {
        schema = M.SCHEMA,
        registry = {
            prefabs = type(registry.prefabs) == "table" and {
                available = registry.prefabs.available == true,
                count = tonumber(registry.prefabs.count),
                sample_count = type(registry.prefabs.names) == "table" and #registry.prefabs.names or 0,
                truncated = registry.prefabs.truncated == true,
            } or { available = false, count = nil, sample_count = 0, truncated = false },
            recipes = type(registry.recipes) == "table" and {
                available = registry.recipes.available == true,
                count = tonumber(registry.recipes.count),
                sample_count = type(registry.recipes.names) == "table" and #registry.recipes.names or 0,
                truncated = registry.recipes.truncated == true,
            } or { available = false, count = nil, sample_count = 0, truncated = false },
            player_components = type(registry.player_components) == "table" and {
                available = registry.player_components.available == true,
                count = tonumber(registry.player_components.count),
                sample_count = type(registry.player_components.names) == "table" and #registry.player_components.names or 0,
                truncated = registry.player_components.truncated == true,
            } or { available = false, count = nil, sample_count = 0, truncated = false },
            runtime_components = {
                enabled = runtime_components.enabled == true,
                available = runtime_components.available == true,
                hooks_registered = tonumber(runtime_components.hooks_registered) or 0,
                hook_failures = tonumber(runtime_components.hook_failures) or 0,
                callback_errors = tonumber(runtime_components.callback_errors) or 0,
                event_count = type(runtime_components.events) == "table" and #runtime_components.events or 0,
                dropped = tonumber(runtime_components.dropped) or 0,
                component_counts = runtime_component_counts,
                observed_prefabs = runtime_observed_prefabs,
                event_sample = runtime_observed_events,
            },
        },
        community_events = {
            enabled = community_events.enabled == true,
            available = community_events.available == true,
            event_count = type(community_event_list) == "table" and #community_event_list or 0,
            dropped = tonumber(community_events.dropped) or 0,
            unverified = true,
            event_sample = {},
        },
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
    for index, event in ipairs(community_event_list) do
        if index > 32 then break end
        if type(event) == "table" then
            analysis.community_events.event_sample[#analysis.community_events.event_sample + 1] = {
                id = tonumber(event.id),
                mod_id = safe_text(event.mod_id, 80),
                kind = safe_text(event.kind, 40),
                message = safe_text(event.message, 500),
                source_verified = false,
            }
        end
    end
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

local function find_snapshot_mod(snapshot, mod_id)
    if type(snapshot) ~= "table" or type(snapshot.mods) ~= "table" then return nil end
    for _, mod in ipairs(snapshot.mods) do
        if type(mod) == "table" and mod.id == mod_id then return mod end
    end
    return nil
end

local function list_contains(values, expected)
    for _, value in ipairs(type(values) == "table" and values or {}) do
        if value == expected then return true end
    end
    return false
end

function M.ExecuteReadOnlyTask(task, snapshot)
    if type(task) ~= "table" or type(task.kind) ~= "string"
        or type(snapshot) ~= "table" or snapshot.schema ~= "modxpector/world-inventory/v2" then
        return "inconclusive", { reason = "invalid_task_or_snapshot" }
    end
    local mod = find_snapshot_mod(snapshot, task.mod_id)
    if mod == nil then return "inconclusive", { reason = "target_mod_not_in_snapshot" } end

    if task.kind == "inspect_load_error" then
        if type(mod.load_error) == "string" and mod.load_error ~= "" then
            return "passed", {
                diagnostic_outcome = "load_error_confirmed",
                error_excerpt = mod.load_error:sub(1, 400),
                signature = type(task.evidence) == "table" and task.evidence.signature or nil,
            }
        end
        return "inconclusive", { reason = "load_error_not_observed" }
    elseif task.kind == "verify_missing_dependency" then
        if mod.dependencies_known == true and list_contains(mod.missing_dependencies, task.related_id) then
            return "passed", { diagnostic_outcome = "dependency_missing_confirmed", dependency = task.related_id }
        end
        return "inconclusive", { reason = "dependency_state_not_confirmed", dependency = task.related_id }
    elseif task.kind == "review_mod_flags" then
        if mod.metadata_available ~= true then
            return "inconclusive", { reason = "mod_metadata_unavailable" }
        end
        if mod.client_only == true and mod.all_clients_required == true then
            return "passed", { diagnostic_outcome = "conflicting_mod_flags_confirmed" }
        end
        return "failed", { diagnostic_outcome = "flag_conflict_not_reproduced" }
    elseif task.kind == "verify_dependency_enabled" then
        if mod.dependencies_known == true and list_contains(mod.disabled_dependencies, task.related_id) then
            return "passed", { diagnostic_outcome = "dependency_disabled_confirmed", dependency = task.related_id }
        end
        local dependency = find_snapshot_mod(snapshot, task.related_id)
        if dependency ~= nil and dependency.enabled == true then
            return "failed", { diagnostic_outcome = "dependency_is_enabled", dependency = task.related_id }
        end
        return "inconclusive", { reason = "dependency_state_not_observed", dependency = task.related_id }
    elseif task.kind == "confirm_load_state" then
        if mod.loaded_known == true and (mod.load_state == "candidate_not_observed_loaded"
            or mod.load_state == "enabled_not_observed_loaded") then
            return "passed", { diagnostic_outcome = "load_state_confirmed", load_state = mod.load_state }
        end
        if mod.loaded == true then
            return "failed", { diagnostic_outcome = "mod_now_observed_loaded" }
        end
        return "inconclusive", { reason = "loaded_state_not_observable" }
    elseif task.kind == "collect_dependency_evidence" then
        if list_contains(mod.unverified_dependencies, task.related_id) then
            return "inconclusive", { reason = "dependency_api_did_not_verify", dependency = task.related_id }
        end
        return "inconclusive", { reason = "no_additional_dependency_evidence", dependency = task.related_id }
    elseif task.kind == "collect_mod_metadata" then
        if mod.metadata_available == false then
            return "inconclusive", { reason = "metadata_unavailable_in_runtime" }
        end
        return "failed", { diagnostic_outcome = "metadata_now_available" }
    elseif task.kind == "review_community_api_compatibility" then
        local apis = type(snapshot.community_apis) == "table" and snapshot.community_apis or {}
        local api = type(apis.dev_tools) == "table" and apis.dev_tools or {}
        if api.version_observed == true and type(api.version) == "number" and api.version > 1 then
            return "passed", { diagnostic_outcome = "major_api_version_change", api = "DevToolsAPI", version = api.version }
        end
        if api.version_observed == true and type(api.version) == "number" then
            return "failed", { diagnostic_outcome = "documented_api_version_observed", api = "DevToolsAPI", version = api.version }
        end
        return "inconclusive", { reason = "community_api_version_not_observed", api = "DevToolsAPI" }
    elseif task.kind == "collect_community_api_evidence" then
        local apis = type(snapshot.community_apis) == "table" and snapshot.community_apis or {}
        local api = type(apis.dev_tools) == "table" and apis.dev_tools or {}
        if api.version_observed == true then
            return "failed", { diagnostic_outcome = "community_api_now_observed", api = "DevToolsAPI", version = api.version }
        end
        return "inconclusive", { reason = "community_api_not_observed", api = "DevToolsAPI" }
    end
    return "inconclusive", { reason = "unsupported_read_only_task", task_kind = task.kind }
end

function M.RunReadOnlyPlan(plan, session, snapshot, limit)
    if type(plan) ~= "table" or plan.schema ~= M.PLAN_SCHEMA or plan.mode ~= "read_only"
        or type(session) ~= "table" or session.schema ~= "modxpector/embedded-ai-session/v1"
        or type(snapshot) ~= "table" or snapshot.schema ~= "modxpector/world-inventory/v2" then
        return { executed = 0, results = {}, next_task = nil, complete = false, error = "invalid_plan_session_or_snapshot" }
    end
    limit = type(limit) == "number" and limit == math.floor(limit) and limit >= 1 and limit <= 200 and limit or 200
    local results = {}
    while #results < limit do
        local task = M.NextTask(plan, session)
        if task == nil then break end
        local status, evidence = M.ExecuteReadOnlyTask(task, snapshot)
        M.RecordTaskResult(session, task.id, status, evidence)
        results[#results + 1] = {
            task_id = task.id,
            kind = task.kind,
            mod_id = task.mod_id,
            status = status,
            evidence = evidence,
        }
    end
    local next_task = M.NextTask(plan, session)
    return {
        executed = #results,
        results = results,
        next_task = next_task,
        complete = next_task == nil,
    }
end

local BUILTIN_SUITE_TOKEN = {}
local BUILTIN_FIXTURE_POLICIES = {
    mam_donharpoon_pickup = {
        owner_mod_id = "metals-and-reforged",
        prefab = "donharpoon",
        count = 1,
    },
}
local BUILTIN_COMMUNITY_SUITES = {
    {
        schema = "modxpector/test-suite/v1",
        id = "mam_donharpoon_pickup",
        owner_mod_id = "metals-and-reforged",
        title = "Metals and More Reforged — Don Harpoon pickup",
        priority = 70,
        allowed_prefabs = { "donharpoon" },
        allowed_recipes = {},
        allowed_actions = { "PICKUP" },
        scenarios = {
            {
                id = "pickup_donharpoon",
                title = "Spawn and pick up the Don Harpoon",
                steps = {
                    {
                        kind = "fixture",
                        operation = "spawn_entity",
                        prefab = "donharpoon",
                        count = 1,
                    },
                    {
                        kind = "action",
                        action = "PICKUP",
                        target = { prefab = "donharpoon", radius = 12 },
                        target_required = true,
                    },
                    {
                        kind = "assert",
                        assertion = {
                            kind = "pickup_target_collected",
                            target_step = 2,
                            prefab = "donharpoon",
                            count = 1,
                        },
                        verifies_step = 2,
                    },
                },
            },
        },
    },
}

function M.GetBuiltinSuites()
    -- Return fresh data so callers cannot mutate the embedded catalog.
    local suites = {}
    for _, suite in ipairs(BUILTIN_COMMUNITY_SUITES) do
        local valid, normalized = M.ValidateSuite(suite, { allow_builtin_fixtures = true })
        if valid then
            normalized._builtin_suite_token = BUILTIN_SUITE_TOKEN
            suites[#suites + 1] = normalized
        end
    end
    return suites
end

local SUITE_ACTION_ALLOWLIST = { WALKTO = true, PICKUP = true }
local SUITE_ASSERTION_ALLOWLIST = {
    pickup_target_collected = true,
    player_inventory_item_count_increased = true,
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
    elseif kind == "pickup_target_collected" then
        local target_step = assertion.target_step
        if not finite_in_range(target_step, 1, index - 1)
            or target_step ~= math.floor(target_step)
            or previous_actions[target_step] ~= "PICKUP"
            or not safe_identifier(assertion.prefab) or prefab_set[assertion.prefab] ~= true then
            return nil
        end
        result.target_step = target_step
        result.prefab = assertion.prefab
    elseif kind == "player_inventory_item_count_increased" then
        local target_step = assertion.target_step
        if not finite_in_range(target_step, 1, index - 1)
            or target_step ~= math.floor(target_step)
            or previous_actions[target_step] ~= "PICKUP"
            or not safe_identifier(assertion.prefab) or prefab_set[assertion.prefab] ~= true then
            return nil
        end
        local count = assertion.count == nil and 1 or assertion.count
        if not finite_in_range(count, 1, 10000) or count ~= math.floor(count) then return nil end
        result.target_step = target_step
        result.prefab = assertion.prefab
        result.count = count
    elseif kind == "player_near_target" or kind == "target_exists" or kind == "target_has_tag" then
        local target_step = assertion.target_step
        if not finite_in_range(target_step, 1, index - 1)
            or target_step ~= math.floor(target_step) or previous_actions[target_step] == nil then return nil end
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

function M.ValidateSuite(suite, options)
    if type(suite) ~= "table" or suite.schema ~= "modxpector/test-suite/v1" then
        return false, "unsupported_suite_schema"
    end
    local allow_builtin_fixtures = type(options) == "table"
        and options.allow_builtin_fixtures == true
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
        local fixture_count = 0
        for index, step in ipairs(scenario.steps) do
            if type(step) ~= "table" then return false, "invalid_step:" .. tostring(index) end
            if step.kind == "fixture" or step.kind == "spawn_entity" then
                local policy = BUILTIN_FIXTURE_POLICIES[suite.id]
                local operation = step.kind == "fixture" and step.operation or "spawn_entity"
                if not allow_builtin_fixtures or policy == nil
                    or suite.owner_mod_id ~= policy.owner_mod_id
                    or index ~= 1 or fixture_count >= 1
                    or operation ~= "spawn_entity"
                    or step.prefab ~= policy.prefab
                    or (step.count ~= nil and step.count ~= policy.count)
                    or step.position ~= nil or step.offset ~= nil then
                    return false, "fixture_not_allowed:" .. tostring(index)
                end
                if prefab_set[policy.prefab] ~= true then
                    return false, "fixture_prefab_not_allowlisted:" .. tostring(index)
                end
                steps[#steps + 1] = {
                    kind = "spawn_entity",
                    prefab = policy.prefab,
                    count = policy.count,
                }
                fixture_count = fixture_count + 1
            elseif step.kind == "action" then
                if type(step.action) ~= "string" or SUITE_ACTION_ALLOWLIST[step.action] ~= true
                    or action_set[step.action] ~= true or step.target_required ~= true then
                    return false, "unsafe_action_step:" .. tostring(index)
                end
                local target = copy_target(step.target, prefab_set)
                if target == nil then return false, "invalid_action_target:" .. tostring(index) end
                local normalized_step = {
                    kind = "action",
                    action = step.action,
                    target = target,
                    target_required = true,
                }
                if step.timeout ~= nil then
                    if not finite_in_range(step.timeout, 1, 120) then return false, "invalid_step_timeout" end
                    normalized_step.timeout = step.timeout
                end
                steps[#steps + 1] = normalized_step
                previous_actions[index] = step.action
            elseif step.kind == "assert" then
                local assertion = copy_assertion(step.assertion, index, previous_actions, prefab_set, recipe_set)
                if assertion == nil then return false, "invalid_assertion_step:" .. tostring(index) end
                local verifies_step = step.verifies_step
                if not finite_in_range(verifies_step, 1, index - 1)
                    or verifies_step ~= math.floor(verifies_step) or previous_actions[verifies_step] == nil then
                    return false, "assertion_must_verify_prior_action:" .. tostring(index)
                end
                if assertion.target_step ~= nil and assertion.target_step ~= verifies_step then
                    return false, "assertion_target_must_match_verified_action:" .. tostring(index)
                end
                if assertion.kind == "pickup_target_collected" then
                    local pickup_action = steps[verifies_step]
                    if type(pickup_action) ~= "table" or pickup_action.kind ~= "action"
                        or pickup_action.action ~= "PICKUP"
                        or type(pickup_action.target) ~= "table"
                        or pickup_action.target.prefab ~= assertion.prefab then
                        return false, "pickup_identity_assertion_must_match_exact_pickup_target:" .. tostring(index)
                    end
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
        local allow_builtin_fixtures = type(candidate) == "table"
            and candidate._builtin_suite_token == BUILTIN_SUITE_TOKEN
        local valid, suite = M.ValidateSuite(candidate, {
            allow_builtin_fixtures = allow_builtin_fixtures,
        })
        if valid and allow_builtin_fixtures then
            suite._builtin_suite_token = BUILTIN_SUITE_TOKEN
        end
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
    local allow_builtin_fixtures = type(suite) == "table"
        and suite._builtin_suite_token == BUILTIN_SUITE_TOKEN
    local valid, normalized = M.ValidateSuite(suite, {
        allow_builtin_fixtures = allow_builtin_fixtures,
    })
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
