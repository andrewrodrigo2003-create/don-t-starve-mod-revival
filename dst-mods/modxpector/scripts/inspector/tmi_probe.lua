-- Read-only TMI widget and public data-shape discovery.
local M = {}

local function safe_field(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return nil
end

local function count_table(value)
    if type(value) ~= "table" then return nil end
    local count = 0
    local ok = pcall(function()
        for _ in pairs(value) do count = count + 1 end
    end)
    return ok and count or nil
end

local function sorted_keys(value)
    if type(value) ~= "table" then return nil end
    local keys = {}
    local ok = pcall(function()
        for key in pairs(value) do
            if type(key) == "string" then keys[#keys + 1] = key end
        end
    end)
    if not ok then return nil end
    table.sort(keys)
    return table.concat(keys, ", ")
end

local function looks_like_tmi_widget(value, key)
    if type(value) ~= "table" then return false end
    local key_name = string.upper(tostring(key or ""))
    local widget_name = string.upper(tostring(safe_field(value, "name") or ""))
    local marker = safe_field(value, "IsTooManyItemsMenuShow")
    local named = key_name:find("TMI", 1, true) ~= nil or widget_name:find("TMI", 1, true) ~= nil
    local has_show = type(safe_field(value, "Show")) == "function"
    local has_hide = type(safe_field(value, "Hide")) == "function"
    return (named or type(marker) == "boolean") and (has_show or has_hide or type(marker) == "boolean")
end

local function find_tmi_widget(container, source)
    if type(container) ~= "table" then return nil, nil end
    local ok, found, found_source = pcall(function()
        for key, value in pairs(container) do
            if looks_like_tmi_widget(value, key) then
                return value, tostring(source) .. "." .. tostring(key)
            end
        end
        return nil, nil
    end)
    if ok then return found, found_source end
    return nil, nil
end

local function scan_widget_children(owner, source)
    local containerroot = safe_field(owner, "containerroot")
    local children = safe_field(containerroot, "children")
    return find_tmi_widget(children, tostring(source) .. ".containerroot.children")
end

local function bounded_table_shape(value, limit)
    if type(value) ~= "table" then return type(value) end
    local numeric, strings, other, scanned = 0, 0, 0, 0
    local cursor = nil
    local truncated = false
    while true do
        local key = next(value, cursor)
        if key == nil then break end
        cursor = key
        scanned = scanned + 1
        if type(key) == "number" then numeric = numeric + 1
        elseif type(key) == "string" then strings = strings + 1
        else other = other + 1 end
        if scanned >= limit then
            truncated = next(value, cursor) ~= nil
            break
        end
    end
    return "table(n=" .. tostring(numeric) .. (truncated and "+" or "")
        .. ",s=" .. tostring(strings) .. (truncated and "+" or "")
        .. ",o=" .. tostring(other) .. (truncated and "+" or "") .. ")"
end

function M.GetListShape(data)
    local ok, shape = pcall(function()
        local list = safe_field(data, "LIST")
        if type(list) ~= "table" then return "LIST=" .. type(list) end
        -- Bound the top-level scan as well as each child-table scan. Sorting
        -- all keys without a scan cap would make this diagnostic proportional
        -- to an untrusted mod's entire catalogue size.
        local keys = {}
        local max_scan = 256
        local scanned = 0
        local cursor = nil
        while scanned < max_scan do
            local key = next(list, cursor)
            if key == nil then break end
            cursor = key
            scanned = scanned + 1
            if type(key) == "string" then keys[#keys + 1] = key end
        end
        local scan_truncated = next(list, cursor) ~= nil
        table.sort(keys)
        if #keys == 0 and not scan_truncated then return "LIST=empty" end
        local parts = {}
        local max_fields = math.min(#keys, 32)
        for index = 1, max_fields do
            local key = keys[index]
            parts[#parts + 1] = key .. "=" .. bounded_table_shape(rawget(list, key), 256)
        end
        if #keys > max_fields then parts[#parts + 1] = "...+" .. tostring(#keys - max_fields) .. " fields" end
        if scan_truncated then parts[#parts + 1] = "... additional fields beyond 256-key scan limit" end
        return table.concat(parts, "; ")
    end)
    return ok and shape or "LIST=unreadable"
end


function M.GetIntegrationStatus(control, data, list_state, network, mod_info)
    network = type(network) == "table" and network or {}
    if type(mod_info) ~= "table" then return "not_detected_in_client_mod_index" end
    if mod_info.enabled ~= true then return "installed_but_disabled" end
    if mod_info.client_only == true and network.is_client ~= true then
        return "client_only_mod_not_visible_in_server_context"
    end
    if network.is_client ~= true then return "client_context_unconfirmed" end
    if network.is_admin == false then
        if mod_info.tmi_admin_gated_documented == true then return "hidden_for_non_admin" end
        return "admin_visibility_unverified_for_this_variant"
    end
    if network.is_admin ~= true then return "admin_status_unconfirmed" end
    if type(data) ~= "table" then return "client_namespace_not_loaded" end
    if list_state ~= "ready" then return "prefab_catalog_incomplete" end
    if type(control) ~= "table" then return "catalog_ready_widget_not_exposed" end
    return "ready"
end

function M.GetControls(globals)
    if type(globals) ~= "table" then
        return nil, nil, "unavailable", "globals_unavailable", nil, false, nil, nil, nil
    end

    local control_root = rawget(globals, "controls")
    local tmi_control = type(control_root) == "table" and rawget(control_root, "TMI") or nil
    local control_source = type(tmi_control) == "table" and "GLOBAL.controls" or "unavailable"

    if type(tmi_control) ~= "table" then
        tmi_control, control_source = find_tmi_widget(control_root, "GLOBAL.controls")
    end
    if type(tmi_control) ~= "table" then
        tmi_control, control_source = scan_widget_children(control_root, "GLOBAL.controls")
    end

    local player = rawget(globals, "ThePlayer")
    local player_hud = safe_field(player, "HUD")
    local player_controls = safe_field(player_hud, "controls")
    if type(tmi_control) ~= "table" then
        local hud_tmi_control = safe_field(player_controls, "TMI")
        if type(hud_tmi_control) == "table" then
            tmi_control = hud_tmi_control
            control_source = "ThePlayer.HUD.controls"
        end
    end
    if type(tmi_control) ~= "table" then
        tmi_control, control_source = find_tmi_widget(player_controls, "ThePlayer.HUD.controls")
    end
    if type(tmi_control) ~= "table" then
        tmi_control, control_source = scan_widget_children(player_controls, "ThePlayer.HUD.controls")
    end
    if type(tmi_control) ~= "table" then
        for key, value in pairs(globals) do
            if type(key) == "string" and key ~= "TOOMANYITEMS"
                and string.upper(key):find("TMI", 1, true) ~= nil
                and looks_like_tmi_widget(value, key) then
                tmi_control = value
                control_source = "GLOBAL." .. key
                break
            end
        end
    end
    if type(tmi_control) ~= "table" then
        local root_keys = sorted_keys(control_root) or "unavailable"
        local hud_keys = sorted_keys(player_controls) or "unavailable"
        control_source = "unavailable; GLOBAL.controls keys=" .. root_keys .. "; HUD.controls keys=" .. hud_keys
    end

    local tmi_data = rawget(globals, "TOOMANYITEMS")
    local tmi_list = safe_field(tmi_data, "LIST")
    local prefab_list = safe_field(tmi_list, "prefablist")
    local show_image_list = safe_field(tmi_list, "showimagelist")
    local list_state
    if tmi_data == nil then
        list_state = "global_missing"
    elseif type(tmi_list) ~= "table" then
        list_state = "list_missing"
    elseif type(prefab_list) ~= "table" then
        list_state = "prefablist_missing"
    elseif count_table(prefab_list) == 0 then
        list_state = "prefablist_empty"
    else
        list_state = "ready"
    end

    local menu_open = safe_field(tmi_control, "IsTooManyItemsMenuShow")
    if type(menu_open) ~= "boolean" then menu_open = nil end
    return tmi_control, tmi_data, control_source, list_state,
        count_table(prefab_list), type(prefab_list) == "table",
        count_table(show_image_list), menu_open, sorted_keys(tmi_list)
end

return M
