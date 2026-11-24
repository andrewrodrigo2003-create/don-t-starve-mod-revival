-- Static contract test for the native Inspector 21.2.23 dashboard.
local function read(path)
    local file = assert(io.open(path, "r"))
    local value = file:read("*a")
    file:close()
    return value
end
local root = "dst-mods/modxpector/"
local info = read(root .. "modinfo.lua")
-- DST runs modinfo.lua in a restricted environment; standard libraries such as
-- string are not guaranteed to exist. Execute it with an intentionally empty env.
local modinfo_chunk = assert(loadfile(root .. "modinfo.lua"))
local modinfo_env = {}
setfenv(modinfo_chunk, modinfo_env)
assert(pcall(modinfo_chunk), "modinfo.lua must load without standard-library globals")
assert(type(modinfo_env.configuration_options) == "table")
assert(#modinfo_env.configuration_options[1].options == 32,
    "hotkey options must include F5-F10 and A-Z")
assert(modinfo_env.configuration_options[1].default == "KEY_F6")
assert(not info:find("string.byte", 1, true))
assert(not info:find("string.char", 1, true))
local main = read(root .. "modmain.lua")
local screen_source = read(root .. "scripts/screens/modinspectorscreen.lua")
local devtools = read(root .. "scripts/inspector/devtools.lua")
local serverdiagnostics = read(root .. "scripts/inspector/serverdiagnostics.lua")
local tmi_probe_source = read(root .. "scripts/inspector/tmi_probe.lua")
local config_snapshot_source = read(root .. "scripts/inspector/config_snapshot.lua")
assert(info:find('version = "5.0.14-dev"', 1, true))
assert(main:find('require, "modxpector/world_inventory"', 1, true))
assert(main:find("WORLD_INVENTORY_MODULE_LOAD_FAILED", 1, true))
assert(main:find("local WorldInventory = INVENTORY_OK and WORLD_INVENTORY or nil", 1, true))
assert(not main:find('ui_pcall(require, "modxpector/world_inventory")', 1, true),
    "Server report must reuse the one startup load and preserve its original error")
assert(main:find("Diagnostics.Collect, GLOBAL, WorldInventory", 1, true))
assert(serverdiagnostics:find("function M.Collect(globals, inventory_module)", 1, true))
assert(serverdiagnostics:find("Load states: known=", 1, true))
assert(main:find("local pcall = (DST_GLOBAL and DST_GLOBAL.pcall) or pcall", 1, true))
assert(main:find("local rawget = (DST_GLOBAL and DST_GLOBAL.rawget) or rawget", 1, true))
assert(main:find("local rawset = (DST_GLOBAL and DST_GLOBAL.rawset) or rawset", 1, true))
assert(main:find("ui_pcall(Screen, GLOBAL, debug_enabled ~= false, runtime_config)", 1, true))
assert(main:find('pcall(require, "modxpector/embedded_ai")', 1, true))
assert(not main:find("TheSim:QueryServer", 1, true), "the embedded AI runtime must not require HTTP")
assert(not main:find("bridge_token.txt", 1, true), "the embedded AI runtime must not require a local token")
assert(not screen_source:find("MODXPECTOR_CAPTURE_LOGS", 1, true))
assert(not screen_source:find("Export-DSTModInspectorLogs.ps1", 1, true))
assert(screen_source:find("local recipes = rawget(DST_GLOBAL, \"AllRecipes\")", 1, true))
assert(screen_source:find("local spawn_prefab = rawget(DST_GLOBAL, \"SpawnPrefab\")", 1, true))
assert(not screen_source:find("type(AllRecipes)", 1, true))
assert(not screen_source:find("type(SpawnPrefab)", 1, true))
-- Startup must not load the developer module; it is required only inside the explicit server-report handler.
assert(main:find('require, "inspector/devtools"', 1, true))
assert(main:find('local function install_server_rpc', 1, true) < main:find('require, "inspector/devtools"', 1, true))
assert(main:find('rawget(GLOBAL, "DST_MOD_INSPECTOR_PENDING_EVENTS")', 1, true))
assert(main:find('rawset(GLOBAL, "DST_MOD_INSPECTOR_PENDING_EVENTS", pending_events)', 1, true))
assert(not main:find("GLOBAL.DST_MOD_INSPECTOR_PENDING_EVENTS", 1, true))
assert(not main:find("GLOBAL.DST_MOD_INSPECTOR_SERVER_REPORT =", 1, true))
assert(main:find('rawset(GLOBAL, "DST_MOD_INSPECTOR_SERVER_REPORT", report_text)', 1, true))
assert(main:find("local function queue_event", 1, true))
assert(not main:find("server_startup_diagnostic", 1, true))
assert(main:find("full diagnostics deferred until requested", 1, true))
assert(not main:find('Devtools.Record("sim_ready"', 1, true))
assert(not main:find('Devtools.Record("player_ready"', 1, true))
-- Diagnostic modules must not resolve GLOBAL/_G during require; globals are injected only after load.
assert(not devtools:find("GLOBAL or _G", 1, true))
assert(not serverdiagnostics:find("GLOBAL or _G", 1, true))
assert(devtools:find("function M.SetGlobals(globals)", 1, true))
assert(screen_source:find("Devtools.SetGlobals(global_env)", 1, true))
assert(main:find("Devtools.SetGlobals(GLOBAL)", 1, true))
-- UI engine lookups must target DST's injected engine global table.
assert(screen_source:find("local DST_GLOBAL", 1, true))
assert(screen_source:find("function(self, global_env, show_debug_info, runtime_config)", 1, true))
assert(screen_source:find("DST_GLOBAL = global_env", 1, true))
assert(main:find("frontend.PushScreen, frontend, screen", 1, true))
assert(main:find("Open key event received.", 1, true))
assert(main:find("Open blocked: expected HUD or pause menu entry", 1, true))
assert(main:find("Dashboard pushed successfully.", 1, true))
assert(main:find("KEY_NAMES[letter_key] = letter_key", 1, true))
assert(screen_source:find('rawget(DST_GLOBAL, "KnownModIndex")', 1, true))
assert(screen_source:find('rawget(DST_GLOBAL, "ThePlayer")', 1, true))
assert(not screen_source:find('_G.', 1, true))
assert(not screen_source:find("ThePlayer and ThePlayer.prefab", 1, true))
assert(not screen_source:find("TheWorld and TheWorld.prefab", 1, true))
assert(not screen_source:find("TheWorld and TheWorld.ismastersim", 1, true))
assert(screen_source:find("self._diagnostic_cache", 1, true))
assert(screen_source:find("self._content_catalogs", 1, true))
assert(screen_source:find("self.show_debug_info = show_debug_info ~= false", 1, true))
assert(not screen_source:find("table.concat(lines, \"\\n\"), mods", 1, true))
assert(devtools:find("21.2.23", 1, true))
assert(info:find('name = "open_key"', 1, true))
assert(info:find('default = "KEY_F6"', 1, true))
assert(info:find("client_only_mod = false", 1, true))
assert(info:find("all_clients_require_mod = true", 1, true))
assert(main:find("AddKeyDownHandler", 1, true))
assert(main:find("PushScreen", 1, true))
assert(not main:find("AddUserCommand", 1, true))
local tabs = {
    "inicio", "mods", "compat", "conteudo", "receitas",
    "testes", "tmi", "servidor", "ferramentas", "ajuda",
}
for _, tab in ipairs(tabs) do
    assert(screen_source:find('"' .. tab .. '"', 1, true))
end
assert(screen_source:find("SetOnClick", 1, true))
assert(screen_source:find("get_tmi_controls", 1, true))
assert(screen_source:find("local tmi_control, tmi_data, tmi_control_source, tmi_list_state, tmi_menu_open", 1, true),
    "TMI scenario must declare menu_open locally under DST strict.lua")
assert(screen_source:find("tmi_control.Show", 1, true))
assert(screen_source:find("TOOMANYITEMS", 1, true))
assert(screen_source:find("PopScreen", 1, true))
assert(screen_source:find("InspectEntity", 1, true))
assert(screen_source:find("AnalyzeMods", 1, true))
assert(screen_source:find("CompareSnapshots", 1, true))
assert(screen_source:find("GetSessionReport", 1, true))
assert(screen_source:find('tmi_list_keys, tmi_status = build_report()', 1, true),
    "General report must build its data from the current diagnostic inventory")
assert(screen_source:find('local report = table.concat(report_lines, "\\n")', 1, true),
    "General report must define its text before exporting it")
assert(screen_source:find('write_export_block("CLIENT_FULL_REPORT", report)', 1, true),
    "General report must export the locally assembled client report")
assert(screen_source:find('write_export_block("CLIENT_SESSION_JOURNAL", journal or "")', 1, true),
    "General report must export the session journal as a separate block")
assert(screen_source:find('write_export_block("SERVER_DIAGNOSTICS", server_report)', 1, true),
    "General report must include server diagnostics when received")
assert(screen_source:find('"REPORT_CHECKLIST"', 1, true)
    and screen_source:find('"NOT_CAPTURED"', 1, true),
    "General report must declare missing server data in a collection checklist")
assert(not screen_source:find('write_export_block("CLIENT_FULL_REPORT", report .. "\\n" .. journal)', 1, true),
    "General report must not reference the former undeclared report variable")

assert(devtools:find("function M.InspectEntity", 1, true))
assert(devtools:find("function M.AnalyzeMods", 1, true))
assert(devtools:find("function M.CompareSnapshots", 1, true))
assert(devtools:find("MAX_EVENTS = 80", 1, true))
assert(screen_source:find("DSTMI_EXPORT_BEGIN", 1, true))
assert(screen_source:find("TMI documented open key:", 1, true))
assert(screen_source:find("GetIntegrationStatus(tmi_control, tmi_data, tmi_list_state, net, tmi_info)", 1, true))
assert(screen_source:find("TMIR oculto para não-admin (comportamento esperado)", 1, true))
assert(screen_source:find("Metadado client-only confere com Workshop", 1, true))
assert(screen_source:find("Visibilidade desta variante para não-admin não documentada", 1, true))
assert(screen_source:find("Widget and Show/Hide are diagnostic hints", 1, true))
assert(screen_source:find("DSTMI_EXPORT_LINE", 1, true))
assert(main:find("log_report_block", 1, true))
assert(main:find("AddModRPCHandler", 1, true))
assert(main:find("AddClientModRPCHandler", 1, true))
assert(main:find("serverdiagnostics", 1, true))
assert(screen_source:find("TEMPLATES.StandardButton(callback, label", 1, true),
    "Action buttons must use native clickable Redux StandardButton")
assert(screen_source:find("button:SetTextColour({ 0, 0, 0, 1 })", 1, true),
    "Action button labels must be black for readability")
assert(screen_source:find("button:SetTextFocusColour({ 0, 0, 0, 1 })", 1, true),
    "Action button focus labels must remain black")
assert(screen_source:find("function InspectorScreen:RefreshNearbyEntities()", 1, true),
    "Inspector must support browsing nearby entities without cursor targeting")
assert(screen_source:find("sim.FindEntities", 1, true),
    "Nearby entity browser must use the engine entity query")
assert(screen_source:find("self.tools_mode == \"entities\"", 1, true),
    "Tools must provide a dedicated entity selection view")
assert(screen_source:find("self.tools_mode == \"detail\"", 1, true),
    "Selecting an entity must open an in-Inspector detail view")
assert(screen_source:find("Devtools.InspectEntity(entity)", 1, true),
    "Entity selection must call the read-only entity inspector")
assert(screen_source:find("self.entity_page = math.min(page_count, self.entity_page + 1)", 1, true),
    "Nearby entity list must support pagination")
assert(screen_source:find("Inspecionar sob cursor", 1, true),
    "Cursor inspection must remain available as an additional option")
assert(screen_source:find("-145, -5", 1, true),
    "Tools action buttons must use the non-overlapping two-column layout")
assert(not screen_source:find('require "widgets/button"', 1, true),
    "Legacy generic Button widget must not be used")
local tmi_probe = assert(loadfile(root .. "scripts/inspector/tmi_probe.lua"))()
local global_tmi = {
    IsTooManyItemsMenuShow = false,
    Show = function() error("probe must not call Show") end,
    Hide = function() error("probe must not call Hide") end,
}
local global_list = { prefablist = { "log", "grass" }, showimagelist = { log = true } }
local control, data, source, list_state, prefab_count, prefab_available, image_count, menu_open, list_keys =
    tmi_probe.GetControls({ controls = { TMI = global_tmi }, TOOMANYITEMS = { LIST = global_list } })
assert(control == global_tmi and source == "GLOBAL.controls" and type(data) == "table")
assert(list_state == "ready" and prefab_count == 2 and prefab_available == true)
assert(image_count == 1 and menu_open == false and list_keys:find("prefablist", 1, true))
local tmi_mod = { enabled = true, client_only = true, tmi_admin_gated_documented = true }
assert(tmi_probe.GetIntegrationStatus(control, data, list_state, { is_client = true, is_admin = true }, tmi_mod) == "ready")
local plain_widget = {}
assert(tmi_probe.GetIntegrationStatus(plain_widget, data, list_state, { is_client = true, is_admin = true }, tmi_mod) == "ready")
assert(tmi_probe.GetIntegrationStatus(nil, { LIST = {} }, "prefablist_missing", { is_client = true, is_admin = true }, tmi_mod) == "prefab_catalog_incomplete")
assert(tmi_probe.GetIntegrationStatus(nil, { LIST = { prefablist = { log = true } } }, "ready", { is_client = true, is_admin = true }, tmi_mod) == "catalog_ready_widget_not_exposed")
assert(tmi_probe.GetIntegrationStatus(nil, nil, "global_missing", { is_client = true, is_admin = false }, tmi_mod) == "hidden_for_non_admin")
assert(tmi_probe.GetIntegrationStatus(nil, nil, "global_missing", { is_client = true, is_admin = false }, { enabled = true, client_only = true }) == "admin_visibility_unverified_for_this_variant")
assert(tmi_probe.GetIntegrationStatus(nil, nil, "global_missing", { is_client = false, is_admin = true }, tmi_mod) == "client_only_mod_not_visible_in_server_context")
assert(tmi_probe.GetIntegrationStatus(nil, nil, "global_missing", { is_client = true, is_admin = true }, { enabled = false, client_only = true }) == "installed_but_disabled")
assert(tmi_probe.GetIntegrationStatus(nil, nil, "global_missing", { is_client = true, is_admin = true }, nil) == "not_detected_in_client_mod_index")
local shape = tmi_probe.GetListShape({ LIST = { items = { alpha = true, beta = true }, prefablist = { [1] = "one", [2] = "two" } } })
local wide = {}
for index = 1, 600 do wide["field_" .. tostring(index)] = {} end
assert(tmi_probe.GetListShape({ LIST = wide }):find("additional fields beyond 256-key scan limit", 1, true))
assert(shape:find("items=table(n=0,s=2,o=0)", 1, true))
assert(shape:find("prefablist=table(n=2,s=0,o=0)", 1, true))
local large = {}
for index = 1, 300 do large[index] = index end
assert(tmi_probe.GetListShape({ LIST = { bulk = large } }):find("n=256+", 1, true))
local renamed_widget = { Show = function() end, Hide = function() end }
local renamed_globals = {
    controls = { TMIR = renamed_widget },
    TOOMANYITEMS = { LIST = { prefablist = { spider = "spider_builder" }, showimagelist = {} } },
}
local renamed_control, _, renamed_source, renamed_state = tmi_probe.GetControls(renamed_globals)
assert(renamed_control == renamed_widget and renamed_source == "GLOBAL.controls.TMIR" and renamed_state == "ready")
local nested_widget = { name = "TMIRMenu", Show = function() end, Hide = function() end }
local nested_globals = {
    controls = { containerroot = { children = { nested_widget } } },
    TOOMANYITEMS = { LIST = { prefablist = { spider = "spider_builder" }, showimagelist = {} } },
}
local nested_control, _, nested_source, nested_state = tmi_probe.GetControls(nested_globals)
assert(nested_control == nested_widget and nested_source:find("containerroot.children", 1, true) and nested_state == "ready")
local global_widget = { Show = function() end, Hide = function() end }
local global_widget_control, _, global_widget_source = tmi_probe.GetControls({
    TMIRWidget = global_widget,
    TOOMANYITEMS = { LIST = { prefablist = { spider = "spider_builder" } } },
})
assert(global_widget_control == global_widget and global_widget_source == "GLOBAL.TMIRWidget")
local hud_tmi = { IsTooManyItemsMenuShow = true }
control, data, source, list_state, prefab_count, prefab_available, image_count, menu_open = tmi_probe.GetControls({
    ThePlayer = { HUD = { controls = { TMI = hud_tmi } } },
    TOOMANYITEMS = { LIST = {} },
})
assert(control == hud_tmi and source == "ThePlayer.HUD.controls" and type(data) == "table")
assert(list_state == "prefablist_missing" and prefab_count == nil and prefab_available == false and menu_open == true)
control, data, source, list_state, prefab_count, prefab_available = tmi_probe.GetControls({
    TOOMANYITEMS = { LIST = { prefablist = {} } },
})
assert(control == nil and list_state == "prefablist_empty" and prefab_available == true and prefab_count == 0)
control, data, source, list_state, prefab_count, prefab_available = tmi_probe.GetControls({})
assert(control == nil and data == nil and source:find("unavailable;", 1, true) == 1 and list_state == "global_missing" and prefab_available == false)
local config_snapshot = assert(loadfile(root .. "scripts/inspector/config_snapshot.lua"))()
local local_config = { open_key = "KEY_F8", show_debug_info = false }
local server_config = { test_mode = true, max_spawn_count = 20 }
local config_sources = {}
local effective = config_snapshot.Read(function(key, get_local_config)
    config_sources[key] = get_local_config
    return (get_local_config and local_config or server_config)[key]
end)
assert(effective.open_key == "KEY_F8" and effective.show_debug_info == false)
assert(effective.test_mode == true and effective.max_spawn_count == 20)
assert(config_sources.open_key == true and config_sources.show_debug_info == true)
assert(config_sources.test_mode == false and config_sources.max_spawn_count == false)
local defaults = config_snapshot.Read(function() return nil end)
assert(defaults.open_key == "KEY_F6" and defaults.show_debug_info == true)
assert(defaults.test_mode == false and defaults.max_spawn_count == 10)
local invalid = config_snapshot.Read(function(key, get_local_config)
    if key == "open_key" and get_local_config == true then return "bad" end
    if key == "max_spawn_count" and get_local_config == false then return 99 end
end)
assert(invalid.open_key == "KEY_F6" and invalid.max_spawn_count == 10)
assert(config_snapshot_source:find("max_spawn_count", 1, true))
print("MODXPECTOR_RECOVERED_UI_STATIC_OK")

assert(not screen_source:find("GLOBAL or _G", 1, true), "screen module must not resolve undeclared engine globals")
assert(not screen_source:find("DST_MOD_INSPECTOR_PENDING_EVENTS", 1, true), "screen must not read server event journal")
assert(screen_source:find('local VERSION = "5.0.14-dev"', 1, true))
assert(screen_source:find("TMIProbe.GetControls(DST_GLOBAL)", 1, true))
assert(screen_source:find("TMI integration state:", 1, true))
assert(tmi_probe_source:find("ThePlayer.HUD.controls", 1, true))
assert(tmi_probe_source:find("prefablist", 1, true))
assert(screen_source:find("TMI LIST state:", 1, true))
assert(screen_source:find("Configuração", 1, true))
assert(screen_source:find("CONFIGURAÇÕES ATIVAS DO MOD", 1, true))
assert(screen_source:find("Abrir/fechar painel:", 1, true))
assert(screen_source:find("Informações técnicas:", 1, true))
assert(screen_source:find("IA embarcada:", 1, true))
assert(screen_source:find("Modo de testes controlados:", 1, true))
assert(screen_source:find("Limite de geração por ação:", 1, true))
assert(screen_source:find("MODXPECTOR — DST MOD INSPECTOR", 1, true))
assert(screen_source:find("self.active_tab == \"config\"", 1, true))
assert(screen_source:find("self.runtime_config", 1, true))
assert(screen_source:find("CONFIGURATION", 1, true))
assert(screen_source:find("source=local_client", 1, true))
assert(screen_source:find("source=server", 1, true))
assert(main:find("CONFIG_SNAPSHOT.Read(GetModConfigData, pcall)", 1, true))
assert(main:find("screens/redux/pausescreen", 1, true))
assert(main:find("menu.AddItem, menu, \"ModXpector\"", 1, true))
assert(screen_source:find("TMIR oculto para não-admin (comportamento esperado)", 1, true))
assert(screen_source:find("TMI controls source:", 1, true))
assert(serverdiagnostics:find("modxpector/server-report/v2", 1, true))
assert(serverdiagnostics:find("version = \"5.0.14-dev\"", 1, true))
assert(serverdiagnostics:find("[ModXpector 5.0.14-dev] SERVER REPORT", 1, true))

-- 21.2.23: viewport-centered native Redux settings-style navigation and native clickable pause entry.
main = read("dst-mods/modxpector/modmain.lua")
assert(main:find('screens/redux/pausescreen', 1, true), "pause screen hook must target Redux pause screen")
assert(main:find('menu.AddItem', 1, true), "pause screen must use native clickable menu item")
assert(main:find('open_inspector(true)', 1, true), "pause menu callback must open Inspector")
local ui = read("dst-mods/modxpector/scripts/screens/modinspectorscreen.lua")
assert(ui:find('TEMPLATES.ScreenRoot', 1, true), "Inspector must use the native centered Redux screen root")
assert(ui:find('TEMPLATES.LeftSideBarBackground', 1, true), "Inspector must use the native Redux settings background")
assert(ui:find('self.root:SetPosition(0, 0)', 1, true), "Inspector must be anchored to viewport center")
assert(ui:find('self.root:SetScale(viewport_scale)', 1, true), "Inspector must scale to the active viewport")
assert(ui:find('screen_width / 1600', 1, true) and ui:find('screen_height / 900', 1, true),
    "Inspector must derive a bounded scale from screen dimensions")
assert(ui:find('TEMPLATES.MenuButton', 1, true), "Navigation must use native clickable Redux menu buttons")
assert(not ui:find('panel_saveslots.tex', 1, true), "Inspector must not use the save-slot panel texture")
assert(not ui:find('GetScreenPos', 1, true), "Panel placement must not depend on world projection or cursor")
assert(ui:find('self.nav:SetPosition(-465, 10)', 1, true), "Inspector must use left navigation rail")
assert(ui:find('{ "IA / Testes", "testes" }', 1, true), "AI and test controls must be discoverable as a named tab")
assert(ui:find('MODXPECTOR_EMBEDDED_AI_STATUS', 1, true), "Dashboard must display embedded AI status")
assert(ui:find('content_first_button', 1, true) and ui:find('content_last_button', 1, true),
    "Prefab catalog must expose first/previous/next/last navigation")
assert(ui:find('« Início', 1, true) and ui:find('‹ Anterior', 1, true)
    and ui:find('Próxima ›', 1, true) and ui:find('Fim »', 1, true),
    "Prefab pagination controls must have explicit labels")
assert(ui:find('self.content_prefabs_button = make_button(self.content, "Prefabs", -130, -145', 1, true)
    and ui:find('self.content_actions_button = make_button(self.content, "Ações", 130, -145', 1, true),
    "Content category selectors must use their own row separate from pagination")
assert(ui:find('self.content_first_button:SetDisabled(self.content_page <= 1)', 1, true)
    and ui:find('self.content_last_button:SetDisabled(self.content_page >= page_count)', 1, true),
    "Prefab navigation must disable boundary controls")
assert(ui:find('"Somente ativos", -270, -185', 1, true)
    and ui:find('"Anterior", -90, -185', 1, true)
    and ui:find('"Próxima", 90, -185', 1, true)
    and ui:find('"Atualizar", 270, -185', 1, true),
    "Mod navigation controls must have non-overlapping horizontal spacing")
assert(ui:find('"Anterior", -270, -215', 1, true)
    and ui:find('"Próxima", -90, -215', 1, true)
    and ui:find('"Atualizar", 90, -215', 1, true)
    and ui:find('"Voltar", 270, -215', 1, true),
    "Nearby entity controls must have non-overlapping horizontal spacing")

-- Navigation discoverability: the AI/Testes and Configuração entries must remain visible.
assert(screen_source:find('{ "IA / Testes", "testes" }', 1, true),
    "AI/Testes must be a visible navigation tab")
assert(screen_source:find('{ "Configuração", "config" }', 1, true),
    "Configuração must be a visible navigation tab")
assert(screen_source:find('menu principal > Mods > ModXpector > Configurar', 1, true),
    "The configuration tab must explain where the user enables AI and test mode")
assert(screen_source:find('A análise principal funciona offline, sem Ollama, Python ou servidor.', 1, true),
    "The UI must state that embedded AI has no external runtime dependency")
print("MODXPECTOR_AI_MENU_DISCOVERABILITY_CONTRACT_OK")


-- Embedded AI must be available offline and visible in the native dashboard.
assert(main:find('pcall(require, "modxpector/embedded_ai")', 1, true),
    "modmain must load the embedded Lua reasoning engine")
assert(main:find('DST_GLOBAL.MODXPECTOR_RUN_EMBEDDED_AI = run_embedded_ai_diagnostics', 1, true),
    "modmain must expose the embedded analysis action to the dashboard")
assert(main:find('DST_GLOBAL.MODXPECTOR_REGISTER_TEST_SUITE = register_embedded_test_suite', 1, true),
    "community mods must be able to register declarative test suites")
assert(main:find('DST_GLOBAL.MODXPECTOR_RUN_AI_SUITE = run_embedded_ai_suite', 1, true),
    "embedded AI must expose a controlled Virtual Player suite runner")
assert(main:find('AddClientModRPCHandler(MODNAME, "plan_ready"', 1, true),
    "Virtual Player must start only after Master validation")
assert(screen_source:find('Executar suite', 1, true),
    "dashboard must expose safe community suite execution")
assert(main:find('WORLD_INVENTORY.Collect, DST_GLOBAL', 1, true),
    "embedded AI must consume the in-game read-only mod inventory")
assert(main:find('EMBEDDED_AI.Analyze, snapshot', 1, true),
    "embedded AI must analyze the observed inventory")
assert(screen_source:find('MODXPECTOR_EMBEDDED_AI_STATUS', 1, true),
    "dashboard must show embedded AI status")
assert(screen_source:find('MODXPECTOR_EMBEDDED_AI_REPORT', 1, true),
    "dashboard must show diagnostic findings")
assert(screen_source:find('Executar análise da IA embarcada', 1, true),
    "dashboard must expose a button for the offline reasoning engine")
assert(not screen_source:find('Ollama local', 1, true),
    "dashboard must not instruct users to run Ollama")
assert(not info:find('name = "ai_bridge_enabled"', 1, true),
    "external bridge must not be a user-facing AI option")
assert(not config_snapshot_source:find('ai_bridge_enabled', 1, true),
    "effective config must not expose the external bridge as the main AI")
print("MODXPECTOR_EMBEDDED_AI_UI_CONTRACT_OK")
