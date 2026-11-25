local root = os.getenv("DST_RUNTIME_ROOT") or "."
local config_path = root .. "/dst-mods/modxpector/scripts/inspector/config_snapshot.lua"
local config_chunk = assert(loadfile(config_path))
local config_module = config_chunk()

local disabled = config_module.Read(function(key)
    if key == "collect_runtime_components" then return nil end
    if key == "test_mode" then return false end
    if key == "laboratory_mode" then return false end
end, pcall)
assert(disabled.collect_runtime_components == false,
    "runtime component observation must default to disabled")
assert(disabled.accept_community_events == false,
    "community event ingestion must default to disabled")
assert(disabled.test_mode == false)
assert(disabled.laboratory_mode == false,
    "world-changing laboratory mode must default to disabled")

local enabled = config_module.Read(function(key)
    if key == "collect_runtime_components" or key == "accept_community_events" or key == "laboratory_mode" then return true end
end, pcall)
assert(enabled.collect_runtime_components == true and enabled.accept_community_events == true,
    "configuration snapshot must expose explicit opt-in for observers")
assert(enabled.laboratory_mode == true,
    "configuration snapshot must expose the separate disposable-lab opt-in")

local modinfo_path = root .. "/dst-mods/modxpector/modinfo.lua"
local modinfo_chunk = assert(loadfile(modinfo_path))
local env = { string = string, table = table }
setfenv(modinfo_chunk, env)
modinfo_chunk()
local options = {}
for _, candidate in ipairs(env.configuration_options or {}) do
    options[candidate.name] = candidate
end
local option = options.collect_runtime_components
assert(option ~= nil and option.default == false,
    "mod configuration must keep runtime observation disabled by default")
assert(type(option.options) == "table" and #option.options == 2
    and option.options[1].data == false and option.options[2].data == true,
    "runtime observation must be a clear opt-in toggle")
local laboratory_option = options.laboratory_mode
assert(laboratory_option ~= nil and laboratory_option.default == false
    and laboratory_option.options[1].data == false and laboratory_option.options[2].data == true,
    "world-changing tests must require a separate explicit disposable-lab opt-in")
local event_option = options.accept_community_events
assert(event_option ~= nil and event_option.default == false
    and event_option.options[1].data == false and event_option.options[2].data == true,
    "community event ingestion must be a separate explicit opt-in toggle")

print("MODXPECTOR_CONFIG_SNAPSHOT_OK")
