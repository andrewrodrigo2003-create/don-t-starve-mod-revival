-- Runtime contracts for the modules shipped in the current ModXpector package.
local root = "dst-mods/modxpector/scripts/inspector/"
local diagnostics = assert(loadfile(root .. "serverdiagnostics.lua"))()
local tmi = assert(loadfile(root .. "tmi_probe.lua"))()
local config = assert(loadfile(root .. "config_snapshot.lua"))()

local infos = {
    ["workshop-a"] = {
        name = "Alpha Mod", version = "1.2", api_version = 10,
        all_clients_require_mod = true,
        dependencies = { "workshop-c", "workshop-missing" },
    },
    ["workshop-b"] = { name = "Client UI", version = "2.0", client_only_mod = true },
    ["workshop-c"] = { name = "Server Utility", version = "3.0", api_version = 10, server_only_mod = true },
    ["workshop-d"] = { name = "Disabled Mod", version = "4.0" },
}
local enabled = { ["workshop-a"] = true, ["workshop-b"] = true, ["workshop-c"] = true }
local index = {
    GetModNames = function() return { "workshop-a", "workshop-b", "workshop-c", "workshop-d" } end,
    GetServerModNames = function() return { "workshop-a", "workshop-c" } end,
    IsModEnabledAny = function(_, id) return enabled[id] == true end,
    GetModInfo = function(_, id) return infos[id] end,
    GetModDependencies = function(_, id, recursive)
        assert(recursive == false)
        return infos[id].dependencies or {}
    end,
    DoesModExistAnyVersion = function(_, id) return id ~= "workshop-missing" end,
}
local globals = {
    TheWorld = { ismastersim = true, prefab = "forest" },
    TheNet = {
        IsDedicated = function() return true end,
        GetIsServer = function() return true end,
    },
    KnownModIndex = index,
    AllRecipes = { a = {}, b = {}, c = {} },
    Prefabs = { a = {}, b = {}, c = {}, d = {} },
}

-- Current report schema and dependency accounting.
local report = diagnostics.Collect(globals)
assert(report.version == "5.0.14-dev")

-- The live diagnostic path must include the detailed load-state inventory when supplied.
local inventory_stub = {
    Collect = function(received_globals)
        assert(received_globals == globals)
        return {
            schema = "modxpector/world-inventory/v2",
            counts = { known = 4, enabled = 3, load_candidates = 3, loaded = 2, failed = 1 },
            mods = {
                { id = "workshop-a", name = "Alpha", load_state = "loaded", workshop_id = "100" },
                { id = "workshop-c", name = "Charlie", load_state = "failed", workshop_id = "300", load_error = "modmain failed" },
            },
        }
    end,
}
local integrated = diagnostics.Collect(globals, inventory_stub)
assert(integrated.inventory.schema == "modxpector/world-inventory/v2")
assert(integrated.text:find("Load states: known=4 enabled=3 candidates=3 loaded=2 failed=1", 1, true))
assert(integrated.text:find("workshop-c | Charlie | failed | Workshop=300", 1, true))
assert(integrated.text:find("Load error: modmain failed", 1, true))
assert(report.schema_id == "modxpector/server-report/v2")
assert(report.legacy_ui_version == "21.2.23")
assert(report.status == "master-ready")
assert(report.known_mod_count == 4)
assert(report.server_candidate_count == 2)
assert(report.enabled_total_count == 3)
assert(report.enabled_server_mod_count == 2)
assert(report.recipe_count == 3 and report.prefab_registry_count == 4)
assert(#report.mods == 2, "client-only and disabled mods must not appear in the server list")
assert(report.mods[1].id == "workshop-a" and report.mods[2].id == "workshop-c")
assert(#report.warnings == 1 and report.warnings[1]:find("workshop%-missing"))
assert(report.warnings[1]:find("Dependência ausente", 1, true))
assert(report.text:find("modxpector/server%-report/v2"))

-- An installed dependency that is disabled is not reported as missing.
local dependency_state = diagnostics.Collect({
    TheWorld = { ismastersim = true, prefab = "forest" },
    KnownModIndex = {
        GetModNames = function() return { "workshop-owner", "workshop-dependency" } end,
        GetServerModNames = function() return { "workshop-owner", "workshop-dependency" } end,
        IsModEnabledAny = function(_, id) return id == "workshop-owner" end,
        GetModInfo = function(_, id)
            if id == "workshop-owner" then return { name = "Owner", dependencies = { "workshop-dependency" } } end
            return { name = "Installed dependency" }
        end,
        DoesModExistAnyVersion = function() return true end,
    },
})
assert(#dependency_state.warnings == 1)
assert(dependency_state.warnings[1]:find("instalada, mas não habilitada", 1, true))
assert(not dependency_state.warnings[1]:find("ausente", 1, true))

-- Transport truncation is bounded and explicitly marked.
local short_report = diagnostics.ToTransportString(report, 100)
assert(#short_report <= 100)
assert(short_report:find("report truncated for network transport", 1, true))
assert(diagnostics.ToTransportString({ text = "short" }, 100) == "short")

-- Missing or throwing engine APIs must degrade to a partial report, not crash.
local partial = diagnostics.Collect({
    TheWorld = { ismastersim = false, prefab = "cave" },
    KnownModIndex = {
        GetModNames = function() error("mock index failure") end,
        GetServerModNames = function() error("mock server list failure") end,
    },
})
assert(partial.status == "not-master")
assert(partial.known_mod_count == nil)
assert(partial.enabled_total_count == 0)
assert(partial.server_candidate_count == 0)
assert(#partial.mods == 0)
local no_world = diagnostics.Collect({})
assert(no_world.status == "world-not-ready")
assert(no_world.world_ready == false)

-- TMI list-shape inspection is read-only and bounded at both levels.
local child = {}
for i = 1, 300 do child[i] = true end
local shape = tmi.GetListShape({ LIST = { prefabs = child, categories = { "tools", "weapons" } } })
assert(shape:find("prefabs=table(n=256+", 1, true))
assert(shape:find("categories=table(n=2", 1, true))
assert(shape:find("LIST=empty", 1, true) == nil)
assert(tmi.GetListShape({ LIST = {} }) == "LIST=empty")
assert(tmi.GetListShape({}) == "LIST=nil")

local large_list = {}
for i = 1, 600 do large_list[string.format("field_%03d", i)] = {} end
local bounded_shape = tmi.GetListShape({ LIST = large_list })
assert(bounded_shape:find("additional fields beyond 256%-key scan limit"))
local _, field_count = bounded_shape:gsub("field_%d%d%d=", "")
assert(field_count <= 32, "TMI shape output must never include more than 32 named fields")

-- Variant-aware TMI status rules must not assume admin gating for every fork.
local function status(mod_info, data, list_state, network, control)
    return tmi.GetIntegrationStatus(control, data, list_state, network, mod_info)
end
assert(status(nil) == "not_detected_in_client_mod_index")
assert(status({ enabled = false }) == "installed_but_disabled")
assert(status({ enabled = true, client_only = true }, nil, nil, { is_client = false }) == "client_only_mod_not_visible_in_server_context")
assert(status({ enabled = true }, nil, nil, { is_client = false }) == "client_context_unconfirmed")
assert(status({ enabled = true, tmi_admin_gated_documented = true }, nil, nil, { is_client = true, is_admin = false }) == "hidden_for_non_admin")
assert(status({ enabled = true }, nil, nil, { is_client = true, is_admin = false }) == "admin_visibility_unverified_for_this_variant")
assert(status({ enabled = true }, nil, nil, { is_client = true }) == "admin_status_unconfirmed")
assert(status({ enabled = true }, nil, "ready", { is_client = true, is_admin = true }) == "client_namespace_not_loaded")
assert(status({ enabled = true }, {}, "missing", { is_client = true, is_admin = true }) == "prefab_catalog_incomplete")
assert(status({ enabled = true }, {}, "ready", { is_client = true, is_admin = true }) == "catalog_ready_widget_not_exposed")
assert(status({ enabled = true }, {}, "ready", { is_client = true, is_admin = true }, {}) == "ready")

-- Config snapshot must use the correct local/server scope and sanitize values.
local calls = {}
local values = {
    open_key = "KEY_F8", show_debug_info = false,
    ai_bridge_enabled = false, test_mode = true, max_spawn_count = 20,
}
local snapshot = config.Read(function(key, local_config)
    calls[key] = local_config
    return values[key]
end, pcall)
assert(snapshot.open_key == "KEY_F8")
assert(snapshot.show_debug_info == false)
assert(snapshot.ai_bridge_enabled == false)
assert(snapshot.test_mode == true)
assert(snapshot.max_spawn_count == 20)
assert(calls.open_key == true and calls.show_debug_info == true)
assert(calls.ai_bridge_enabled == false and calls.test_mode == false and calls.max_spawn_count == false)
local defaults = config.Read(function(key) return ({ open_key = "INVALID", max_spawn_count = 999 })[key] end, pcall)
assert(defaults.open_key == "KEY_F6" and defaults.max_spawn_count == 10)

print("MODXPECTOR_CURRENT_MODULES_OK")
