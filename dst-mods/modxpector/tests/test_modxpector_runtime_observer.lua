local root = os.getenv("DST_RUNTIME_ROOT") or "."
local path = root .. "/dst-mods/modxpector/scripts/modxpector/runtime_observer.lua"
local Observer = assert(loadfile(path))()

local globals = { rawset = rawset }
local hooks = {}
local disabled, disabled_state = Observer.Register(function() error("must not register") end,
    globals, false, pcall)
assert(disabled == false and disabled_state.reason == "disabled_by_configuration")
assert(next(hooks) == nil)

local missing, missing_state = Observer.Register(nil, globals, true, pcall)
assert(missing == false and missing_state.reason == "component_post_init_api_unavailable")

local now = 42.5
local ok, state = Observer.Register(function(name, callback)
    hooks[name] = callback
end, globals, true, pcall, function() return now end)
assert(ok == true and state.available == true and state.registered == true)
assert(state.hooks_registered == #Observer.GetAllowlist())
assert(state.hook_failures == 0)

local original = { prefab = "skeletonservant" }
local component = { inst = original }
hooks.health(component)
hooks.health(component)
hooks.workable({ inst = { prefab = "tree" } })
assert(original.prefab == "skeletonservant" and component.inst == original,
    "observer must not mutate component or entity objects")

local snapshot = Observer.Snapshot(globals)
assert(snapshot.enabled and snapshot.available)
assert(snapshot.hooks_registered == #Observer.GetAllowlist())
assert(#snapshot.events == 3 and snapshot.dropped == 0)
assert(snapshot.components[1].name == "health" and snapshot.components[1].count == 2)
assert(snapshot.components[2].name == "workable" and snapshot.components[2].count == 1)
assert(snapshot.events[1].component == "health" and snapshot.events[1].prefab == "skeletonservant")
assert(snapshot.events[1].time == 42.5)

snapshot.events[1].prefab = "tampered"
local fresh = Observer.Snapshot(globals)
assert(fresh.events[1].prefab == "skeletonservant",
    "snapshot must not expose mutable internal event storage")

for i = 1, 300 do
    hooks.inventory({ inst = { prefab = "chest_" .. tostring(i) } })
end
local bounded = Observer.Snapshot(globals)
assert(#bounded.events == 256 and bounded.dropped == 47,
    "event storage must be bounded and count dropped observations")
local inventory_count
for _, item in ipairs(bounded.components) do
    if item.name == "inventory" then inventory_count = item.count end
end
assert(inventory_count == 300, "component counts must continue after the event buffer is full")

local partial_observer = assert(loadfile(path))()
local partial_hooks = {}
local partial_ok, partial_state = partial_observer.Register(function(name, callback)
    if name == "health" then error("synthetic hook registration failure") end
    partial_hooks[name] = callback
end, { rawset = rawset }, true, pcall)
assert(partial_ok == true and partial_state.hook_failures == 1)
assert(partial_state.hooks_registered == #Observer.GetAllowlist() - 1)

local failed_observer = assert(loadfile(path))()
local failed_ok, failed_state = failed_observer.Register(function() error("all hooks unavailable") end,
    { rawset = rawset }, true, pcall)
assert(failed_ok == false and failed_state.hook_failures == #Observer.GetAllowlist())
assert(failed_state.available == false and failed_state.reason == "no_component_hooks_registered")

print("MODXPECTOR_RUNTIME_OBSERVER_V1_OK")
