-- Read the effective mod configuration for display in the Inspector UI.
-- The caller supplies DST's GLOBAL.pcall because the mod sandbox may not
-- expose the standard pcall directly.
local M = {}

function M.Read(getter, safe_pcall)
    local protected_call = safe_pcall or pcall
    local function read(key, default, get_local_config)
        if type(getter) ~= "function" then return default end
        local ok, value = protected_call(getter, key, get_local_config)
        if ok and value ~= nil then return value end
        return default
    end

    -- UI preferences are local-client settings; test/spawn controls follow
    -- the server's effective configuration, matching modmain behavior.
    local open_key = read("open_key", "KEY_F6", true)
    if type(open_key) ~= "string" or not string.match(open_key, "^KEY_[A-Z0-9]+$") then
        open_key = "KEY_F6"
    end
    local max_spawn_count = tonumber(read("max_spawn_count", 10, false)) or 10
    if max_spawn_count ~= 5 and max_spawn_count ~= 10 and max_spawn_count ~= 20 then
        max_spawn_count = 10
    end

    return {
        open_key = open_key,
        show_debug_info = read("show_debug_info", true, true) ~= false,
        test_mode = read("test_mode", false, false) == true,
        max_spawn_count = max_spawn_count,
    }
end

return M
