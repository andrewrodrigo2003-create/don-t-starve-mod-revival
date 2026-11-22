-- Resolve engine globals from the environment injected by DST.
-- Server-authoritative, read-only diagnostics for ModXpector 5.0.14-dev.
-- Only call Collect from the master simulation.
local M = {}

local function safe_method(object, method, ...)
    if object == nil or type(object[method]) ~= "function" then
        return nil
    end
    local ok, result = pcall(object[method], object, ...)
    if ok then return result end
    return nil
end

local function count_table(value)
    if type(value) ~= "table" then
        return nil
    end
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    return count
end

function M.Collect(globals, inventory_module)
    if globals == nil then return { text = "Ambiente do servidor não foi injetado." } end
    local world = globals.TheWorld
    local net = globals.TheNet
    local index = globals.KnownModIndex
    local all_names = safe_method(index, "GetModNames")
    local server_names = safe_method(index, "GetServerModNames")
    local enabled = {}
    local mod_rows = {}
    local warnings = {}
    local enabled_count = 0
    local server_candidate_count = type(server_names) == "table" and #server_names or 0

    if type(all_names) == "table" then
        -- Build the complete enabled set before checking dependency relationships.
        for _, mod_id in ipairs(all_names) do
            if type(mod_id) == "string" and safe_method(index, "IsModEnabledAny", mod_id) == true then
                enabled[mod_id] = true
                enabled_count = enabled_count + 1
            end
        end
        for _, mod_id in ipairs(all_names) do
            if type(mod_id) == "string" then
                local info = safe_method(index, "GetModInfo", mod_id) or {}
                local is_enabled = enabled[mod_id] == true
                local client_only = info.client_only_mod == true
                local all_clients = info.all_clients_require_mod == true
                local server_only = info.server_only_mod == true
                if client_only and all_clients then
                    warnings[#warnings + 1] = "Flags incompatíveis em " .. mod_id
                end
                if is_enabled and not client_only then
                    mod_rows[#mod_rows + 1] = {
                        id = mod_id,
                        name = type(info.name) == "string" and info.name or mod_id,
                        version = tostring(info.version or "?"),
                        api = tostring(info.api_version or "?"),
                        all_clients = all_clients,
                        server_only = server_only,
                    }
                end
                if is_enabled then
                    local dependency_list = safe_method(index, "GetModDependencies", mod_id, false)
                    if type(dependency_list) ~= "table" then dependency_list = info.dependencies end
                    if type(dependency_list) == "table" then
                        for _, dependency in ipairs(dependency_list) do
                            if type(dependency) == "string" then
                                local existence_api = index ~= nil and type(index.DoesModExistAnyVersion) == "function"
                                local exists
                                if existence_api then
                                    exists = safe_method(index, "DoesModExistAnyVersion", dependency)
                                end
                                if existence_api and exists == false then
                                    warnings[#warnings + 1] = "Dependência ausente: " .. mod_id .. " -> " .. dependency
                                elseif exists == true and enabled[dependency] ~= true then
                                    warnings[#warnings + 1] = "Dependência instalada, mas não habilitada: " .. mod_id .. " -> " .. dependency
                                elseif not existence_api and enabled[dependency] ~= true then
                                    warnings[#warnings + 1] = "Dependência não confirmada: " .. mod_id .. " -> " .. dependency
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(mod_rows, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    table.sort(warnings)

    local inventory_snapshot
    if type(inventory_module) == "table" and type(inventory_module.Collect) == "function" then
        local inventory_ok, snapshot = pcall(inventory_module.Collect, globals)
        if inventory_ok and type(snapshot) == "table" then
            inventory_snapshot = snapshot
        else
            warnings[#warnings + 1] = "Inventário detalhado indisponível: " .. tostring(snapshot)
        end
    end

    local recipe_count = count_table(globals.AllRecipes)
    local prefab_registry_count = count_table(globals.Prefabs)
    local world_ready = world ~= nil
    local is_master = world_ready and world.ismastersim == true
    local dedicated = safe_method(net, "IsDedicated") == true
    local is_server = safe_method(net, "GetIsServer")
    local report = {
        schema = 1, -- retained for legacy report readers
        schema_id = "modxpector/server-report/v2",
        version = "5.0.14-dev",
        legacy_ui_version = "21.2.23",
        side = "server",
        world_ready = world_ready,
        world_prefab = world_ready and tostring(world.prefab or "unknown") or "unavailable",
        is_master = is_master,
        dedicated = dedicated,
        net_is_server = is_server,
        known_mod_count = type(all_names) == "table" and #all_names or nil,
        server_candidate_count = server_candidate_count,
        enabled_server_mod_count = #mod_rows,
        enabled_total_count = enabled_count,
        recipe_count = recipe_count,
        prefab_registry_count = prefab_registry_count,
        mods = mod_rows,
        inventory = inventory_snapshot,
        warnings = warnings,
        status = world_ready and (is_master and "master-ready" or "not-master") or "world-not-ready",
    }

    local lines = {
        "[ModXpector 5.0.14-dev] SERVER REPORT",
        "Report schema: modxpector/server-report/v2",
        "Legacy UI baseline: 21.2.23",
        "Status: " .. report.status,
        "World: " .. report.world_prefab,
        "Master simulation: " .. tostring(report.is_master),
        "Dedicated server: " .. tostring(report.dedicated),
        "TheNet server: " .. tostring(report.net_is_server),
        "Known mod entries: " .. tostring(report.known_mod_count or "unavailable"),
        "Server mod candidates: " .. tostring(report.server_candidate_count),
        "Enabled server mods: " .. tostring(report.enabled_server_mod_count),
        "Enabled known mods total: " .. tostring(report.enabled_total_count),
    }
    if inventory_snapshot ~= nil and type(inventory_snapshot.counts) == "table" then
        local counts = inventory_snapshot.counts
        lines[#lines + 1] = string.format(
            "Load states: known=%s enabled=%s candidates=%s loaded=%s failed=%s",
            tostring(counts.known or 0), tostring(counts.enabled or 0),
            tostring(counts.load_candidates or 0), tostring(counts.loaded or "unknown"),
            tostring(counts.failed or 0))
        lines[#lines + 1] = "Load confirmation details:"
        local detail_count = 0
        for _, mod in ipairs(inventory_snapshot.mods or {}) do
            if mod.load_state == "failed" or mod.load_state == "loaded"
                or mod.load_state == "enabled_not_confirmed"
                or mod.load_state == "candidate_not_observed_loaded"
                or mod.load_state == "enabled_not_observed_loaded" then
                detail_count = detail_count + 1
                if detail_count <= 40 then
                    lines[#lines + 1] = string.format("- %s | %s | %s | Workshop=%s",
                        tostring(mod.id), tostring(mod.name), tostring(mod.load_state),
                        tostring(mod.workshop_id or "n/a"))
                    if mod.load_error ~= nil then
                        lines[#lines + 1] = "  Load error: " .. tostring(mod.load_error)
                    end
                    for _, missing in ipairs(mod.missing_dependencies or {}) do
                        lines[#lines + 1] = "  Missing dependency: " .. tostring(missing)
                    end
                    for _, disabled in ipairs(mod.disabled_dependencies or {}) do
                        lines[#lines + 1] = "  Installed dependency not enabled: " .. tostring(disabled)
                    end
                    for _, unverified in ipairs(mod.unverified_dependencies or {}) do
                        lines[#lines + 1] = "  Dependency could not be verified: " .. tostring(unverified)
                    end
                end
            end
        end
        if detail_count > 40 then
            lines[#lines + 1] = string.format("... %d additional load-state entries omitted", detail_count - 40)
        end
    else
        lines[#lines + 1] = "Load states: detailed inventory unavailable"
    end
    lines[#lines + 1] = "AllRecipes entries: " .. tostring(report.recipe_count or "unavailable")
    lines[#lines + 1] = "Prefab registry entries: " .. tostring(report.prefab_registry_count or "unavailable")
    lines[#lines + 1] = "Enabled server mod list:"
    for i = 1, math.min(#mod_rows, 60) do
        local mod = mod_rows[i]
        lines[#lines + 1] = string.format("- %s | %s | API %s | all-clients=%s", mod.id, mod.name, mod.api, tostring(mod.all_clients))
    end
    if #mod_rows > 60 then
        lines[#lines + 1] = "... " .. tostring(#mod_rows - 60) .. " additional mods omitted from display"
    end
    lines[#lines + 1] = "Warnings:"
    if #warnings == 0 then
        lines[#lines + 1] = "- No metadata warnings found (this is not proof of compatibility)."
    else
        for i = 1, math.min(#warnings, 40) do
            lines[#lines + 1] = "- " .. warnings[i]
        end
    end
    report.text = table.concat(lines, "\n")
    return report
end

function M.ToTransportString(report, max_chars)
    local text = type(report) == "table" and report.text or ""
    max_chars = tonumber(max_chars) or 7000
    max_chars = math.max(0, math.floor(max_chars))
    if #text > max_chars then
        local marker = "\n[report truncated for network transport]"
        if max_chars <= #marker then
            return marker:sub(1, max_chars)
        end
        text = text:sub(1, max_chars - #marker) .. marker
    end
    return text
end

return M
