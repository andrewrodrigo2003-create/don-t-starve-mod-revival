-- Resolve engine globals from the environment injected by DST.
local DST_GLOBAL = nil
local pcall_fn = nil
-- DST Mod Inspector 21.2.23 developer diagnostics.
-- Read-only helpers. No engine functions are replaced and no gameplay state is mutated.
local M = {}
local MAX_EVENTS = 80
local events = {}
local sequence = 0

function M.SetGlobals(globals)
    DST_GLOBAL = globals
    pcall_fn = globals and globals.pcall or nil
end

local function safe_call(object, method, ...)
    if object == nil or type(object[method]) ~= "function" or type(pcall_fn) ~= "function" then return nil end
    local results = { pcall_fn(object[method], object, ...) }
    if results[1] then return unpack(results, 2) end
    return nil
end

local function safe_count(value)
    if type(value) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function clean(value, limit)
    local text = tostring(value == nil and "?" or value):gsub("[\r\n]", " ")
    limit = limit or 100
    if #text > limit then text = text:sub(1, limit - 3) .. "..." end
    return text
end

function M.Record(kind, detail, globals)
    if globals ~= nil then M.SetGlobals(globals) end
    globals = globals or DST_GLOBAL
    sequence = sequence + 1
    if globals == nil then return end
    local gettime = globals.GetTime
    local now = type(gettime) == "function" and gettime() or 0
    events[#events + 1] = { id = sequence, time = now, kind = clean(kind, 32), detail = clean(detail, 180) }
    while #events > MAX_EVENTS do table.remove(events, 1) end
end

function M.GetSessionReport()
    local lines = { "DST MOD INSPECTOR — SESSION JOURNAL", "Eventos registrados: " .. tostring(#events) }
    for _, event in ipairs(events) do
        lines[#lines + 1] = string.format("#%03d t=%.2f [%s] %s", event.id, tonumber(event.time) or 0, event.kind, event.detail)
    end
    return table.concat(lines, "\n"), #events
end

function M.AnalyzeMods(globals)
    if globals ~= nil then M.SetGlobals(globals) end
    globals = globals or DST_GLOBAL
    if globals == nil then return { available = false, lines = { "Ambiente do jogo ainda não foi injetado." } } end
    local index = globals.KnownModIndex
    local names = safe_call(index, "GetModNames")
    if type(names) ~= "table" then return { available = false, lines = { "KnownModIndex indisponível nesta sessão." } } end
    local enabled, rows, warnings, edges = {}, {}, {}, {}
    for _, id in ipairs(names) do
        if type(id) == "string" and safe_call(index, "IsModEnabledAny", id) == true then enabled[id] = true end
    end
    for _, id in ipairs(names) do
        if type(id) == "string" then
            local info = safe_call(index, "GetModInfo", id) or {}
            if enabled[id] then
                local deps = info.dependencies
                local missing = {}
                if type(deps) == "table" then
                    for _, dep in ipairs(deps) do
                        local depid = type(dep) == "table" and (dep.modname or dep.name or dep.id) or dep
                        if type(depid) == "string" and depid ~= "" then
                            edges[#edges + 1] = clean(info.name or id, 50) .. " -> " .. clean(depid, 70)
                            if enabled[depid] ~= true then missing[#missing + 1] = depid end
                        end
                    end
                end
                rows[#rows + 1] = { id=id, name=clean(info.name or id, 72), version=clean(info.version or "?", 24), dependencies=type(deps)=="table" and #deps or 0 }
                if #missing > 0 then warnings[#warnings + 1] = clean(info.name or id, 50) .. ": dependências declaradas não identificadas como ativas: " .. table.concat(missing, ", ") end
                if info.client_only_mod == true and info.all_clients_require_mod == true then
                    warnings[#warnings + 1] = clean(info.name or id, 50) .. ": flags client_only_mod e all_clients_require_mod simultaneamente ativas."
                end
            end
        end
    end
    local lines = { "ANÁLISE DE MODS (metadados; não prova conflitos de runtime)", "Mods ativos identificados: " .. tostring(#rows), "Avisos de metadados: " .. tostring(#warnings) }
    for _, warning in ipairs(warnings) do lines[#lines + 1] = "[AVISO] " .. warning end
    lines[#lines + 1] = "MAPA DE DEPENDÊNCIAS DECLARADAS (não é prova de interação runtime):"
    if #edges == 0 then lines[#lines + 1] = "Nenhuma dependência declarada foi exposta." end
    for _, edge in ipairs(edges) do lines[#lines + 1] = edge end
    if #warnings == 0 then lines[#lines + 1] = "Nenhuma inconsistência de dependência/flags encontrada nos metadados expostos." end
    return { available=true, rows=rows, warnings=warnings, lines=lines }
end

function M.InspectEntity(entity)
    if entity == nil or safe_call(entity, "IsValid") == false then return { "Nenhuma entidade válida sob o cursor." } end
    local lines = { "INSPEÇÃO DE ENTIDADE", "Prefab: " .. clean(entity.prefab, 80), "GUID: " .. clean(entity.GUID, 32) }
    local position = safe_call(entity, "GetPosition")
    local x, y, z
    if position ~= nil then x, y, z = safe_call(position, "Get") end
    if type(x) == "number" and type(y) == "number" and type(z) == "number" then
        lines[#lines + 1] = string.format("Posição: %.1f, %.1f, %.1f", x, y, z)
    end
    local tags = safe_call(entity, "GetTags")
    if type(tags) == "table" then
        local tag_names = {}
        for tag, value in pairs(tags) do
            tag_names[#tag_names + 1] = tostring(type(tag) == "number" and value or tag)
        end
        table.sort(tag_names)
        lines[#lines + 1] = "Tags: " .. table.concat(tag_names, ", ")
    end
    local components = entity.components
    local component_names = {}
    if type(components) == "table" then for name in pairs(components) do component_names[#component_names+1] = tostring(name) end end
    table.sort(component_names)
    lines[#lines + 1] = "Componentes (" .. tostring(#component_names) .. "): " .. table.concat(component_names, ", ")
    local replica = entity.replica
    local replica_names = {}
    if type(replica) == "table" then for name in pairs(replica) do replica_names[#replica_names+1] = tostring(name) end end
    table.sort(replica_names)
    lines[#lines + 1] = "Réplicas: " .. table.concat(replica_names, ", ")
    lines[#lines + 1] = "AnimState: " .. tostring(entity.AnimState ~= nil) .. " | Physics: " .. tostring(entity.Physics ~= nil) .. " | Network: " .. tostring(entity.Network ~= nil)
    return lines
end

function M.SnapshotMods(globals)
    if globals ~= nil then M.SetGlobals(globals) end
    globals = globals or DST_GLOBAL
    if globals == nil then return { available = false, lines = { "Ambiente do jogo ainda não foi injetado." } } end
    local index = globals.KnownModIndex
    local names = safe_call(index, "GetModNames")
    if type(names) ~= "table" then return nil, "Inventário indisponível." end
    local snapshot = {}
    for _, id in ipairs(names) do
        if type(id) == "string" and safe_call(index, "IsModEnabledAny", id) == true then
            local info = safe_call(index, "GetModInfo", id) or {}
            snapshot[id] = { name=clean(info.name or id, 80), version=clean(info.version or "?", 32) }
        end
    end
    return snapshot
end

function M.CompareSnapshots(before, after)
    if type(before) ~= "table" or type(after) ~= "table" then return { "Capture dois snapshots antes de comparar." } end
    local added, removed, changed = {}, {}, {}
    for id, current in pairs(after) do
        local old = before[id]
        if old == nil then added[#added+1] = current.name .. " (" .. id .. ")"
        elseif old.version ~= current.version then changed[#changed+1] = current.name .. ": " .. old.version .. " → " .. current.version end
    end
    for id, old in pairs(before) do if after[id] == nil then removed[#removed+1] = old.name .. " (" .. id .. ")" end end
    table.sort(added); table.sort(removed); table.sort(changed)
    local lines = { "COMPARAÇÃO DE SNAPSHOTS", "Adicionados: " .. #added, "Removidos/desativados: " .. #removed, "Versões alteradas: " .. #changed }
    for _, value in ipairs(added) do lines[#lines+1] = "+ " .. value end
    for _, value in ipairs(removed) do lines[#lines+1] = "- " .. value end
    for _, value in ipairs(changed) do lines[#lines+1] = "~ " .. value end
    if #added + #removed + #changed == 0 then lines[#lines+1] = "Nenhuma diferença entre os dois snapshots." end
    return lines
end

return M
