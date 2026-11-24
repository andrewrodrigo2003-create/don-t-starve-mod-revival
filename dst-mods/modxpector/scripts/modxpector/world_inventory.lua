-- Read-only inventory of mods known to and participating in the current DST session.
-- It never reads/writes other mods' source files or changes mod settings.
-- GetModsToLoad is called with usecached=true to avoid a disk rescan/mutation.
-- Do not resolve GLOBAL/_G while requiring this module: DST strict sandbox
-- environments differ. Engine globals and pcall are injected into Collect().
local M = {}
local MAX_MODS = 400

local function safe_call(protected_call, object, method, ...)
    if object == nil or type(object[method]) ~= "function"
        or type(protected_call) ~= "function" then
        return false, nil
    end
    local ok, result = protected_call(object[method], object, ...)
    if ok then return true, result end
    return false, nil
end

local function clean_string(value, fallback, limit)
    if type(value) ~= "string" then return fallback end
    value = value:gsub("[%z\1-\8\11\12\14-\31]", " ")
    limit = limit or 160
    if #value > limit then value = value:sub(1, limit) end
    return value
end

local function to_set(values)
    local result = {}
    if type(values) == "table" then
        for _, value in ipairs(values) do
            if type(value) == "string" then result[value] = true end
        end
    end
    return result
end

local MAX_REGISTRY_NAMES = 256
local MAX_PLAYER_COMPONENT_NAMES = 128

local function collect_registry_names(value, limit)
    if type(value) ~= "table" then
        return { available = false, count = nil, names = {}, truncated = false }
    end
    local names = {}
    for key in pairs(value) do
        if type(key) == "string" then names[#names + 1] = key end
    end
    table.sort(names)
    local count = #names
    while #names > limit do table.remove(names) end
    return { available = true, count = count, names = names, truncated = count > #names }
end

local function workshop_id(mod_id)
    if type(mod_id) ~= "string" then return nil end
    return mod_id:match("^workshop%-(%d+)$")
end

local function collect_failures(manager)
    local result = {}
    local failures = manager and manager.failedmods
    if type(failures) == "table" then
        for _, entry in ipairs(failures) do
            if type(entry) == "table" and type(entry.name) == "string" then
                result[entry.name] = clean_string(entry.error, "Falha sem mensagem", 1200)
            end
        end
    end
    return result
end

local function dependency_list(index, mod_id, known_set, protected_call)
    local ok, dependencies = safe_call(protected_call, index, "GetModDependencies", mod_id, false)
    if not ok or type(dependencies) ~= "table" then return {}, {}, {}, {}, false end

    local normalized, missing, disabled, unverified, seen = {}, {}, {}, {}, {}
    for _, dependency in ipairs(dependencies) do
        if type(dependency) == "string" and not seen[dependency] then
            seen[dependency] = true
            normalized[#normalized + 1] = dependency
            local exists_ok, exists = safe_call(protected_call, index, "DoesModExistAnyVersion", dependency)
            if exists_ok then
                if exists ~= true then
                    missing[#missing + 1] = dependency
                else
                    local enabled_ok, is_enabled = safe_call(protected_call, index, "IsModEnabledAny", dependency)
                    if enabled_ok and is_enabled ~= true then
                        disabled[#disabled + 1] = dependency
                    end
                end
            elseif known_set[dependency] == true then
                local enabled_ok, is_enabled = safe_call(protected_call, index, "IsModEnabledAny", dependency)
                if enabled_ok and is_enabled ~= true then
                    disabled[#disabled + 1] = dependency
                end
            else
                unverified[#unverified + 1] = dependency
            end
        end
    end
    table.sort(normalized)
    table.sort(missing)
    table.sort(disabled)
    table.sort(unverified)
    return normalized, missing, disabled, unverified, true
end

function M.Collect(globals)
    globals = type(globals) == "table" and globals or {}
    local protected_call = type(globals.pcall) == "function" and globals.pcall or nil
    local index = globals.KnownModIndex
    local names_ok, all_names = safe_call(protected_call, index, "GetModNames")
    local server_names_ok, server_names = safe_call(protected_call, index, "GetServerModNames")
    local client_names_ok, client_names = safe_call(protected_call, index, "GetClientModNames")
    local load_names_ok, load_names = safe_call(protected_call, index, "GetModsToLoad", true)
    local server_set = to_set(server_names)
    local client_set = to_set(client_names)
    local load_set = to_set(load_names)
    local known_set = to_set(all_names)

    local manager = globals.ModManager
    local loaded_names = manager and manager.enabledmods
    local loaded_observable = type(loaded_names) == "table"
    local loaded_set = to_set(loaded_names)
    local failures = collect_failures(manager)
    local devtools_api = globals.DevToolsAPI
    local devtools_api_present = type(devtools_api) == "table"
        and type(devtools_api.GetAPIVersion) == "function"
    local devtools_api_version
    local devtools_api_version_observed = false
    if devtools_api_present then
        local version_ok, version = safe_call(protected_call, devtools_api, "GetAPIVersion")
        if version_ok and type(version) == "number"
            and version == version and version ~= math.huge and version ~= -math.huge then
            devtools_api_version = version
            devtools_api_version_observed = true
        end
    end


    local mods, seen = {}, {}
    local counts = {
        known = 0,
        enabled = 0,
        load_candidates = 0,
        loaded = 0,
        failed = 0,
        prefabs = prefab_registry.count,
        recipes = recipe_registry.count,
        player_components = player_components.count,
        server_enabled = 0,
        client_enabled = 0,
        server_classified = server_names_ok and type(server_names) == "table" and #server_names or 0,
        client_classified = client_names_ok and type(client_names) == "table" and #client_names or 0,
    }

    if names_ok and type(all_names) == "table" then
        for _, mod_id in ipairs(all_names) do
            if type(mod_id) == "string" and not seen[mod_id] then
                seen[mod_id] = true
                counts.known = counts.known + 1

                local enabled_ok, enabled_value = safe_call(protected_call, index, "IsModEnabledAny", mod_id)
                local enabled = enabled_ok and enabled_value == true or false
                local info_ok, info = safe_call(protected_call, index, "GetModInfo", mod_id)
                local metadata_available = info_ok and type(info) == "table"
                if not metadata_available then info = {} end

                local client_only = info.client_only_mod == true
                local server_only = info.server_only_mod == true
                local load_candidate = load_names_ok and type(load_names) == "table"
                    and load_set[mod_id] == true or false
                local loaded = loaded_observable and loaded_set[mod_id] == true or false
                local failure = failures[mod_id]
                local dependencies, missing_dependencies, disabled_dependencies, unverified_dependencies, dependencies_known = dependency_list(index, mod_id, known_set, protected_call)
                local id = workshop_id(mod_id)

                if enabled then counts.enabled = counts.enabled + 1 end
                if load_candidate then counts.load_candidates = counts.load_candidates + 1 end
                if loaded then counts.loaded = counts.loaded + 1 end
                if failure ~= nil then counts.failed = counts.failed + 1 end
                if enabled and not client_only then counts.server_enabled = counts.server_enabled + 1 end
                if enabled and not server_only then counts.client_enabled = counts.client_enabled + 1 end

                local enabled_field, load_candidate_field, loaded_field
                if enabled_ok then enabled_field = enabled end
                if load_names_ok and type(load_names) == "table" then load_candidate_field = load_candidate end
                if loaded_observable then loaded_field = loaded end

                local server_enabled, client_enabled
                if enabled_ok then
                    server_enabled = enabled and not client_only
                    client_enabled = enabled and not server_only
                end

                local load_state = "unknown"
                if loaded then
                    load_state = "loaded"
                elseif failure ~= nil then
                    load_state = "failed"
                elseif loaded_observable and load_candidate then
                    load_state = "candidate_not_observed_loaded"
                elseif loaded_observable and enabled then
                    load_state = "enabled_not_observed_loaded"
                elseif load_candidate then
                    load_state = "candidate"
                elseif enabled then
                    load_state = "enabled_not_confirmed"
                elseif enabled_ok then
                    load_state = "disabled"
                end

                mods[#mods + 1] = {
                    id = clean_string(mod_id, "unknown", 180),
                    workshop_id = id,
                    is_workshop = id ~= nil,
                    name = clean_string(info.name, mod_id, 180),
                    version = clean_string(tostring(info.version or "?"), "?", 48),
                    api_version = clean_string(tostring(info.api_version or "?"), "?", 48),
                    metadata_available = metadata_available,
                    enabled = enabled_field,
                    enabled_known = enabled_ok,
                    load_candidate = load_candidate_field,
                    load_candidate_known = load_names_ok and type(load_names) == "table",
                    loaded = loaded_field,
                    loaded_known = loaded_observable,
                    load_state = load_state,
                    load_error = failure,
                    server_classified = server_set[mod_id] == true,
                    client_classified = client_set[mod_id] == true,
                    server_enabled = server_enabled,
                    client_enabled = client_enabled,
                    server_enabled_known = enabled_ok,
                    client_enabled_known = enabled_ok,
                    client_only = client_only,
                    server_only = server_only,
                    all_clients_required = info.all_clients_require_mod == true,
                    priority = tonumber(info.priority),
                    dependencies = dependencies,
                    dependencies_known = dependencies_known,
                    missing_dependencies = missing_dependencies,
                    disabled_dependencies = disabled_dependencies,
                    unverified_dependencies = unverified_dependencies,
                }
            end
        end
    end

    table.sort(mods, function(a, b) return a.id < b.id end)
    local truncated = #mods > MAX_MODS
    while #mods > MAX_MODS do table.remove(mods) end

    local world = globals.TheWorld
    local net = globals.TheNet
    local prefab_registry = collect_registry_names(globals.Prefabs, MAX_REGISTRY_NAMES)
    local recipe_registry = collect_registry_names(globals.AllRecipes, MAX_REGISTRY_NAMES)
    local player = globals.ThePlayer
    local player_components = collect_registry_names(
        type(player) == "table" and player.components or nil,
        MAX_PLAYER_COMPONENT_NAMES)
    local world_name = world ~= nil and clean_string(world.prefab, "unknown", 80) or "unknown"
    local is_master = world ~= nil and world.ismastersim == true
    local os_table = globals.os or os
    local timestamp = os_table and type(os_table.time) == "function" and os_table.time() or 0

    return {
        schema = "modxpector/world-inventory/v2",
        captured_at = timestamp,
        world = {
            prefab = world_name,
            is_master_sim = is_master,
            is_dedicated = select(2, safe_call(protected_call, net, "IsDedicated")) == true,
            is_server = select(2, safe_call(protected_call, net, "GetIsServer")) == true,
        },
        capabilities = {
            known_mod_list = names_ok and type(all_names) == "table",
            server_classification = server_names_ok and type(server_names) == "table",
            client_classification = client_names_ok and type(client_names) == "table",
            load_candidates = load_names_ok and type(load_names) == "table",
            loaded_mod_list = loaded_observable,
            failed_mod_list = manager ~= nil and type(manager.failedmods) == "table",
            prefab_registry = prefab_registry.available,
            recipe_registry = recipe_registry.available,
            player_component_list = player_components.available,
        },
        registry = {
            prefabs = prefab_registry,
            recipes = recipe_registry,
            player_components = player_components,
        },
        counts = counts,
        truncated = truncated,
        mods = mods,
        community_apis = {
            dev_tools = {
                available = devtools_api_present,
                version = devtools_api_version,
                version_observed = devtools_api_version_observed,
            },
        },
    }
end

return M
