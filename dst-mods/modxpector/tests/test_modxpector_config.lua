local root = os.getenv("DST_RUNTIME_ROOT") or "."
local config_path = root .. "/dst-mods/modxpector/scripts/inspector/config_snapshot.lua"
local config_chunk = assert(loadfile(config_path))
local config_module = config_chunk()

local disabled = config_module.Read(function(key)
    if key == "collect_runtime_components" then return nil end
    if key == "test_mode" then return false end
end, pcall)
assert(disabled.collect_runtime_components == false,
    "runtime component observation must default to disabled")
assert(disabled.test_mode == false)

local enabled = config_module.Read(function(key)
    if key == "collect_runtime_components" then return true end
end, pcall)
assert(enabled.collect_runtime_components == true,
    "configuration snapshot must expose explicit opt-in")

local modinfo_path = root .. "/dst-mods/modxpector/modinfo.lua"
local modinfo_chunk = assert(loadfile(modinfo_path))
local env = {}
setfenv(modinfo_chunk, env)
modinfo_chunk()
local option
for _, candidate in ipairs(env.configuration_options or {}) do
    if candidate.name == "collect_runtime_components" then option = candidate end
end
assert(option ~= nil and option.default == false,
    "mod configuration must keep runtime observation disabled by default")
assert(type(option.options) == "table" and #option.options == 2
    and option.options[1].data == false and option.options[2].data == true,
    "runtime observation must be a clear opt-in toggle")

print("MODXPECTOR_CONFIG_SNAPSHOT_OK")
