-- ModXpector 5.0.14-dev; recovered from the legacy Inspector 21.2.23 UI
-- Client-side dashboard. All local probes are defensive and read-only.
-- Engine globals are injected by modmain when the screen is constructed.
-- The server event journal is consumed by modmain only on explicit request.
local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local TEMPLATES = require "widgets/redux/templates"
local Devtools = require "inspector/devtools"
local TMIProbe = require "inspector/tmi_probe"
local DST_GLOBAL

local VERSION = "5.0.14-dev"
local TMI_TERMS = { "too many items", "too many items plus" }
local TMI_WORKSHOP_IDS = {
    ["workshop-551338671"] = "Too Many Items (legacy)",
    ["workshop-1365141672"] = "Too Many Items Plus",
    ["workshop-3192890119"] = "Fix For Too Many Items",
    ["workshop-3638290455"] = "Too Many Items Rearranged",
}

local function write_export_block(kind, content)
    print("[DSTMI_EXPORT_BEGIN] " .. tostring(kind) .. " | version=" .. VERSION)
    for line in tostring(content or ""):gmatch("[^\n]+") do
        print("[DSTMI_EXPORT_LINE] " .. line)
    end
    print("[DSTMI_EXPORT_END] " .. tostring(kind))
end

local function safe_call(object, method, ...)
    if object == nil or type(object[method]) ~= "function" then return nil end
    local ok, value = pcall(object[method], object, ...)
    if ok then return value end
    return nil
end

local function count_table(value)
    if type(value) ~= "table" then return nil end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function mod_inventory()
    local index = rawget(DST_GLOBAL, "KnownModIndex")
    local names = safe_call(index, "GetModNames")
    if type(names) ~= "table" then return nil end
    local result = {}
    for _, id in ipairs(names) do
        if type(id) == "string" then
            local info = safe_call(index, "GetModInfo", id) or {}
            local enabled = safe_call(index, "IsModEnabledAny", id)
            result[#result + 1] = {
                id = id,
                name = type(info.name) == "string" and info.name or id,
                version = tostring(info.version or "?"),
                enabled = enabled == true,
                client_only = info.client_only_mod == true,
                server_only = info.server_only_mod == true,
                all_clients = info.all_clients_require_mod == true,
                api_version = tostring(info.api_version or "?"),
                dependency_count = type(info.dependencies) == "table" and #info.dependencies or 0,
            }
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

local function detect_tmi(mods)
    if type(mods) ~= "table" then return nil, "Lista de mods indisponível." end
    for _, mod in ipairs(mods) do
        local name = mod.name:lower()
        if TMI_WORKSHOP_IDS[mod.id] ~= nil then
            mod.family_name = TMI_WORKSHOP_IDS[mod.id]
            if mod.id == "workshop-3638290455" then
                mod.tmi_client_only_documented = true
                mod.tmi_admin_gated_documented = true
                mod.tmi_open_key = "T"
            end
            return mod
        end
        for _, term in ipairs(TMI_TERMS) do
            if name:find(term, 1, true) then return mod end
        end
    end
    return nil, "Too Many Items não identificado pelo nome. Pode estar instalado com outro título."
end

local function get_tmi_controls()
    return TMIProbe.GetControls(DST_GLOBAL)
end

local function network_info()
    local net = rawget(DST_GLOBAL, "TheNet")
    return {
        is_client = safe_call(net, "GetIsClient"),
        is_server = safe_call(net, "GetIsServer"),
        is_admin = safe_call(net, "GetIsServerAdmin"),
        is_dedicated = safe_call(net, "GetServerIsDedicated"),
    }
end

local function build_report()
    local mods = mod_inventory()
    local tmi = detect_tmi(mods)
    local tmi_control, tmi_data, tmi_control_source, tmi_list_state,
        tmi_prefab_count, tmi_prefab_list_available, tmi_show_image_count,
        tmi_menu_open, tmi_list_keys = get_tmi_controls()
    local tmi_status = TMIProbe.GetIntegrationStatus(tmi_control, tmi_data, tmi_list_state, network_info(), tmi)
    return mods, tmi, tmi_control, tmi_data, tmi_prefab_count,
        tmi_control_source, tmi_list_state, tmi_prefab_list_available,
        tmi_show_image_count, tmi_menu_open, tmi_list_keys, tmi_status
end

local function make_button(parent, label, x, y, callback, scale)
    -- Use the same Redux ImageButton template as native DST option screens.
    -- The previous generic constructor used the wrong texture naming contract,
    -- leaving action labels black and without a reliable clickable image state.
    local factor = scale or 0.72
    local width = math.floor(300 * factor)
    local height = math.floor(64 * factor)
    local button = parent:AddChild(TEMPLATES.StandardButton(callback, label, { width, height }))
    button:SetOnClick(callback)
    button:SetPosition(x, y)
    button:SetFont(CHATFONT)
    button:SetDisabledFont(CHATFONT)
    button:SetTextColour({ 0, 0, 0, 1 })
    button:SetTextFocusColour({ 0, 0, 0, 1 })
    button:SetTextDisabledColour({ 0.25, 0.25, 0.25, 1 })
    button.scale_on_focus = false
    button.move_on_click = false
    return button
end

local function make_navigation_button(parent, label, x, y, callback)
    local button = parent:AddChild(TEMPLATES.MenuButton(label, callback))
    button:SetPosition(x, y)
    button:SetScale(0.88)
    return button
end

local InspectorScreen = Class(Screen, function(self, global_env, show_debug_info, runtime_config)
    DST_GLOBAL = global_env
    if type(Devtools.SetGlobals) == "function" then Devtools.SetGlobals(global_env) end
    Screen._ctor(self, "ModInspectorScreen")
    self.show_debug_info = show_debug_info ~= false
    self.active_tab = "inicio"
    self.mods_page = 1
    self.mods_enabled_only = false
    self.content_page = 1
    self.content_kind = "prefabs"
    self.devtools_report = nil
    self.tools_mode = "actions"
    self.nearby_entities = {}
    self.entity_page = 1
    self.mod_snapshot_a = nil
    self.mod_snapshot_b = nil
    self.last_scenario = nil
    self.last_scenario_report = nil
    self.status = "Painel híbrido: diagnóstico mestre + interface local."
    self.ai_goal_text = "Aproxime-se de um tufo de grama próximo e confirme que está a até 4 unidades dele."
    self.ai_prefabs_text = "grass"
    self.ai_actions_text = "WALKTO"
    -- The DST camera keeps the local player near the center of the viewport.
    -- Use the same proportional, middle-anchored root as native Redux screens;
    -- world-to-screen projection added no useful movement and was resolution fragile.
    self.root = self:AddChild(TEMPLATES.ScreenRoot("inspector_root"))
    self.root:SetPosition(0, 0)

    -- Scale the complete dashboard to the actual viewport. The previous fixed
    -- 1280x720 coordinate layout overflowed or looked oversized at smaller resolutions.
    local frontend = rawget(global_env, "TheFrontEnd")
    local size_ok, screen_width, screen_height = pcall(function()
        return frontend:GetScreenSize()
    end)
    local viewport_scale = 1
    if size_ok and type(screen_width) == "number" and type(screen_height) == "number"
        and screen_width > 0 and screen_height > 0 then
        viewport_scale = math.max(0.70, math.min(1, screen_width / 1600, screen_height / 900))
    end
    self.viewport_scale = viewport_scale
    self.root:SetScale(viewport_scale)

    -- Reuse the game's actual Redux settings background and left navigation rail.
    self.backdrop = self.root:AddChild(TEMPLATES.LeftSideBarBackground())

    self.title = self.root:AddChild(Text(HEADERFONT, 32, "MODXPECTOR — DST MOD INSPECTOR"))
    self.title:SetPosition(-470, 325)
    self.title:SetHAlign(ANCHOR_LEFT)
    self.title:SetColour(UICOLOURS.GOLD_SELECTED)

    self.subtitle = self.root:AddChild(Text(CHATFONT, 22, "Diagnóstico, compatibilidade e ferramentas"))
    self.subtitle:SetPosition(-470, 289)
    self.subtitle:SetHAlign(ANCHOR_LEFT)
    self.subtitle:SetColour(UICOLOURS.GREY)

    self.title_divider = self.root:AddChild(Image("images/frontend_redux.xml", "achievements_divider_top.tex"))
    self.title_divider:SetPosition(145, 265)
    self.title_divider:SetScale(0.78, 0.52)

    self.nav = self.root:AddChild(Widget("inspector_navigation"))
    self.nav:SetPosition(-465, 10)
    self.content = self.root:AddChild(Widget("inspector_content"))
    self.content:SetPosition(115, 0)
    self.status_text = self.root:AddChild(Text(CHATFONT, 20, self.status))
    self.status_text:SetPosition(115, -320)
    self.status_text:SetColour(UICOLOURS.GREY)

    self.nav_buttons = {}
    local tabs = {
        { "Início", "inicio" }, { "Mods", "mods" }, { "Compatibilidade", "compat" },
        { "Conteúdo", "conteudo" }, { "Receitas", "receitas" }, { "IA / Testes", "testes" },
        { "TMI", "tmi" }, { "Servidor", "servidor" }, { "Ferramentas", "ferramentas" },
        { "Configuração", "config" }, { "Ajuda", "ajuda" },
    }
    -- Native Redux menu buttons: gold labels, focus overlay and controller navigation.
    for i, tab in ipairs(tabs) do
        local y = 190 - (i - 1) * 43
        local button = make_navigation_button(self.nav, tab[1], 0, y, function()
            self.active_tab = tab[2]
            self:Refresh()
        end)
        self.nav_buttons[tab[2]] = button
    end
    make_button(self.root, "Fechar  [ESC]", 115, -365, function() self:Close() end, 0.62)
    self:Refresh()
end)

function InspectorScreen:SetStatus(message)
    self.status = tostring(message or "")
    self.status_text:SetString(self.status)
end

function InspectorScreen:ClearContent()
    if self.content ~= nil then self.content:KillAllChildren() end
end

function InspectorScreen:AddLine(text, y, size)
    local line = self.content:AddChild(Text(BODYTEXTFONT, size or 23, tostring(text)))
    line:SetPosition(0, y)
    line:SetRegionSize(900, 42)
    line:SetHAlign(ANCHOR_LEFT)
    line:SetVAlign(ANCHOR_TOP)
    return line
end

function InspectorScreen:Close()
    local frontend = rawget(DST_GLOBAL, "TheFrontEnd")
    if frontend ~= nil then safe_call(frontend, "PopScreen") end
end

function InspectorScreen:SetServerReport(report_text)
    self.server_report = tostring(report_text or "")
    if self.active_tab == "servidor" then
        self:Refresh()
    end
    self:SetStatus("Relatório do servidor recebido.")
end

function InspectorScreen:RunScenario(scenario)
    local checks = {}
    local tmi_info = nil
    local tmi_control, tmi_data, tmi_control_source, tmi_list_state, tmi_menu_open = nil, nil, nil, nil, nil
    local function check(label, passed)
        local sequence = #checks + 1
        checks[#checks + 1] = {
            id = string.upper(scenario) .. "-" .. string.format("%03d", sequence),
            label = label,
            passed = passed == true,
        }
    end
    if scenario == "world" then
        check("Jogador carregado", rawget(DST_GLOBAL, "ThePlayer") ~= nil)
        check("Mundo carregado", rawget(DST_GLOBAL, "TheWorld") ~= nil)
        check("Índice de mods disponível", type(rawget(DST_GLOBAL, "KnownModIndex")) == "table")
        check("Catálogo de prefabs disponível", type(rawget(DST_GLOBAL, "Prefabs")) == "table")
    elseif scenario == "tmi" then
        local net = network_info()
        local mods = mod_inventory()
        tmi_info = detect_tmi(mods)
        check("TMI detectado na lista de mods do cliente", type(tmi_info) == "table")
        check("TMI habilitado no cliente", type(tmi_info) == "table" and tmi_info.enabled == true)
        if type(tmi_info) == "table" and tmi_info.tmi_client_only_documented == true then
            check("Metadado client-only confere com Workshop", tmi_info.client_only == true)
        end
        check("Contexto de cliente confirmado", net.is_client == true)
        check("Status de administrador consultável", type(net.is_admin) == "boolean")
        if type(tmi_info) == "table" and tmi_info.enabled == true and net.is_client == true
            and tmi_info.tmi_admin_gated_documented == true and net.is_admin == false then
            -- The Workshop author documents this behavior specifically for TMIR.
            check("TMIR oculto para não-admin (comportamento esperado)", true)
            check("Atalho documentado do TMIR: tecla T", tmi_info.tmi_open_key == "T")
        elseif type(tmi_info) == "table" and tmi_info.enabled == true and net.is_client == true and net.is_admin == false then
            -- For TMI variants without a verified admin-gating contract, do not infer visibility behavior.
            check("Visibilidade desta variante para não-admin não documentada", true)
            print("[ModXpector TMI] non-admin visibility is unverified for this TMI variant; data probe skipped")
        elseif type(tmi_info) == "table" and tmi_info.enabled == true and net.is_client == true and net.is_admin == true then
            tmi_control, tmi_data, tmi_control_source, tmi_list_state,
                tmi_prefab_count, tmi_prefab_list_available, tmi_show_image_count,
                tmi_menu_open = get_tmi_controls()
            check("Namespace TOOMANYITEMS carregado no cliente", type(tmi_data) == "table")
            check("TOOMANYITEMS.LIST disponível", type(tmi_data) == "table" and type(tmi_data.LIST) == "table")
            check("Catálogo de prefabs do TMI disponível", tmi_prefab_list_available == true)
            -- Widget and Show/Hide are diagnostic hints, not required API contracts.
            print("[ModXpector TMI] widget=" .. tostring(type(tmi_control) == "table")
                .. " source=" .. tostring(tmi_control_source)
                .. " list_state=" .. tostring(tmi_list_state)
                .. " prefab_count=" .. tostring(tmi_prefab_count)
                .. " image_count=" .. tostring(tmi_show_image_count)
                .. " menu_open=" .. tostring(tmi_menu_open)
                .. " open_key=T (Workshop documented)"
                .. " list_shape=" .. TMIProbe.GetListShape(tmi_data)
                .. " status=" .. TMIProbe.GetIntegrationStatus(tmi_control, tmi_data, tmi_list_state, net, tmi_info))
        else
            check("Contexto de cliente e permissão admin disponíveis", net.is_client == true and net.is_admin == true)
        end
    else
        check("AllRecipes disponível", type(rawget(DST_GLOBAL, "AllRecipes")) == "table")
        check("Prefabs disponível", type(rawget(DST_GLOBAL, "Prefabs")) == "table")
        check("ACTIONS disponível", type(rawget(DST_GLOBAL, "ACTIONS")) == "table")
    end
    local passed = 0
    local lines = { "DST MOD INSPECTOR SCENARIO: " .. scenario }
    for _, result in ipairs(checks) do
        if result.passed then passed = passed + 1 end
        lines[#lines + 1] = (result.passed and "[PASS]" or "[INFO]")
            .. "[" .. result.id .. "] " .. result.label
    end
    if scenario == "tmi" then
        local net = network_info()
        local integration_status = TMIProbe.GetIntegrationStatus(tmi_control, tmi_data, tmi_list_state, net, tmi_info)
        lines[#lines + 1] = "Admin: " .. tostring(net.is_admin) .. " | dedicado: " .. tostring(net.is_dedicated)
        lines[#lines + 1] = "TMI integration state: " .. integration_status
        lines[#lines + 1] = "TMI LIST shape: " .. TMIProbe.GetListShape(tmi_data)
    end
    lines[#lines + 1] = "Resultado: " .. tostring(passed) .. "/" .. tostring(#checks)
    self.last_scenario = scenario
    self.last_scenario_id = string.upper(scenario) .. "-" .. string.format("%03d", #checks)
    self.last_scenario_report = table.concat(lines, "\n")
    self.last_scenario_passed = passed
    self.last_scenario_total = #checks
    print("[DST Mod Inspector]\n" .. self.last_scenario_report)
    self:SetStatus("Cenário " .. scenario .. ": " .. passed .. "/" .. #checks .. " verificações.")
    self:Refresh()
end

function InspectorScreen:RefreshNearbyEntities()
    local player = rawget(DST_GLOBAL, "ThePlayer")
    local sim = rawget(DST_GLOBAL, "TheSim")
    self.nearby_entities = {}
    if player == nil or sim == nil or player.Transform == nil or type(sim.FindEntities) ~= "function" then
        self:SetStatus("A busca de entidades não está disponível nesta sessão.")
        return self.nearby_entities
    end
    local ok, x, y, z = pcall(function() return player.Transform:GetWorldPosition() end)
    if not ok then return self.nearby_entities end
    local found_ok, found = pcall(sim.FindEntities, sim, x, y, z, 16)
    if not found_ok or type(found) ~= "table" then return self.nearby_entities end
    for _, entity in ipairs(found) do
        if entity ~= nil and entity ~= player and (type(entity.IsValid) ~= "function" or safe_call(entity, "IsValid") ~= false) then
            local visible = entity.entity == nil or type(entity.entity.IsVisible) ~= "function" or safe_call(entity.entity, "IsVisible") ~= false
            if visible then self.nearby_entities[#self.nearby_entities + 1] = entity end
        end
    end
    table.sort(self.nearby_entities, function(a, b)
        local function distance_sq(entity)
            local ok_distance, value = pcall(function() return player:GetDistanceSqToInst(entity) end)
            if ok_distance and type(value) == "number" then return value end
            local ok_pos, ex, ey, ez = pcall(function() return entity.Transform:GetWorldPosition() end)
            if ok_pos then local dx, dy, dz = ex-x, ey-y, ez-z; return dx*dx + dy*dy + dz*dz end
            return math.huge
        end
        return distance_sq(a) < distance_sq(b)
    end)
    return self.nearby_entities
end

function InspectorScreen:Refresh()
    for tab_id, button in pairs(self.nav_buttons or {}) do
        if button ~= nil and button.text ~= nil and type(button.SetTextColour) == "function" then
            button:SetTextColour(tab_id == self.active_tab and UICOLOURS.GOLD_SELECTED or UICOLOURS.GOLD_CLICKABLE)
        end
    end
    self:ClearContent()
    local cached = self._diagnostic_cache
    if cached == nil then
        cached = { build_report() }
        self._diagnostic_cache = cached
    end
    local mods, tmi, tmi_control, tmi_data, tmi_prefab_count =
        cached[1], cached[2], cached[3], cached[4], cached[5]
    local show_debug_info = self.show_debug_info
    local player = rawget(DST_GLOBAL, "ThePlayer")
    local world = rawget(DST_GLOBAL, "TheWorld")
    local recipes = rawget(DST_GLOBAL, "AllRecipes")
    local prefabs = rawget(DST_GLOBAL, "Prefabs")
    local spawn_prefab = rawget(DST_GLOBAL, "SpawnPrefab")
    if self.active_tab == "inicio" then
        self:AddLine("Bem-vindo ao painel de diagnóstico do seu mundo.", 205, 27)
        self:AddLine("Jogador: " .. tostring(player and player.prefab or "indisponível"), 150)
        self:AddLine("Mundo: " .. tostring(world and world.prefab or "indisponível"), 112)
        self:AddLine("Mods identificados: " .. tostring(mods and #mods or "indisponível"), 74)
        self:AddLine("Too Many Items: " .. tostring(tmi and tmi.name or "não detectado"), 36)
        self:AddLine("Escolha uma categoria acima. As verificações são locais e não modificam o mundo.", -20, 20)
        if show_debug_info then
            self:AddLine("APIs: receitas " .. tostring(type(rawget(DST_GLOBAL, "AllRecipes")) == "table")
                .. " | prefabs " .. tostring(type(rawget(DST_GLOBAL, "Prefabs")) == "table")
                .. " | mods " .. tostring(rawget(DST_GLOBAL, "KnownModIndex") ~= nil), -50, 17)
        end
        make_button(self.content, "Atualizar diagnóstico", 0, -105, function()
            self._diagnostic_cache = nil
            self:Refresh()
            self:SetStatus("Diagnóstico atualizado.")
        end, 0.7)
    elseif self.active_tab == "mods" then
        self:AddLine("INVENTÁRIO DE MODS", 210, 27)
        if mods == nil then
            self:AddLine("KnownModIndex não forneceu a lista nesta sessão.", 150)
        else
            local filtered = {}
            for _, mod in ipairs(mods) do
                if not self.mods_enabled_only or mod.enabled then filtered[#filtered + 1] = mod end
            end
            local page_size = 7
            local page_count = math.max(1, math.ceil(#filtered / page_size))
            self.mods_page = math.max(1, math.min(self.mods_page, page_count))
            local first = (self.mods_page - 1) * page_size + 1
            local last = math.min(#filtered, first + page_size - 1)
            for index = first, last do
                local mod = filtered[index]
                local side = mod.client_only and "cliente" or (mod.server_only and "servidor" or (mod.all_clients and "todos" or "compartilhado"))
                local line = (mod.enabled and "[ATIVO] " or "[OFF] ") .. mod.name .. " v" .. mod.version
                    .. " | " .. side .. " | API " .. mod.api_version .. " | deps " .. tostring(mod.dependency_count)
                self:AddLine(line, 160 - (index - first) * 38, 17)
            end
            self:AddLine("Página " .. tostring(self.mods_page) .. "/" .. tostring(page_count)
                .. " • " .. tostring(#filtered) .. " mods no filtro", -125, 18)
            self.mods_filter_button = make_button(self.content,
                self.mods_enabled_only and "Mostrar todos" or "Somente ativos", -270, -185, function()
                    self.mods_enabled_only = not self.mods_enabled_only
                    self.mods_page = 1
                    self:Refresh()
                end, 0.58)
            self.mods_prev_button = make_button(self.content, "Anterior", -90, -185, function()
                self.mods_page = math.max(1, self.mods_page - 1)
                self:Refresh()
            end, 0.58)
            self.mods_next_button = make_button(self.content, "Próxima", 90, -185, function()
                self.mods_page = math.min(page_count, self.mods_page + 1)
                self:Refresh()
            end, 0.58)
            self.mods_reload_button = make_button(self.content, "Atualizar", 270, -185, function()
                self.mods_page = 1
                self._diagnostic_cache = nil
                self:Refresh()
                self:SetStatus("Lista de mods atualizada.")
            end, 0.58)
        end
    elseif self.active_tab == "compat" then
        self:AddLine("COMPATIBILIDADE DA SESSÃO", 210, 27)
        self:AddLine("Modo: " .. (world and world.ismastersim and "servidor/mestre" or "cliente"), 165, 20)
        self:AddLine("Jogador/mundo: " .. tostring(player and player.prefab or "?")
            .. " / " .. tostring(world and world.prefab or "?"), 130, 18)
        if mods == nil then
            self:AddLine("Metadados dos mods indisponíveis.", 80, 20)
        else
            local sides = { client = 0, server = 0, all = 0, shared = 0 }
            local unknown_api = 0
            local dependency_total = 0
            for _, mod in ipairs(mods) do
                if mod.client_only then sides.client = sides.client + 1
                elseif mod.server_only then sides.server = sides.server + 1
                elseif mod.all_clients then sides.all = sides.all + 1
                else sides.shared = sides.shared + 1 end
                if mod.api_version == "?" then unknown_api = unknown_api + 1 end
                dependency_total = dependency_total + mod.dependency_count
            end
            self:AddLine("Mods: " .. tostring(#mods) .. " | cliente: " .. sides.client
                .. " | servidor: " .. sides.server, 85, 18)
            self:AddLine("Todos clientes: " .. sides.all .. " | compartilhados/indef.: " .. sides.shared, 50, 18)
            self:AddLine("Dependências declaradas: " .. dependency_total .. " | API desconhecida: " .. unknown_api, 15, 18)
        end
        local net = network_info()
        self:AddLine("TMI: " .. tostring(tmi and (tmi.family_name or tmi.name) or "não detectado")
            .. " | menu API: " .. tostring(tmi_control and type(tmi_control.Show) == "function"), -35, 18)
        local _, _, control_source, list_state, prefab_count, prefab_available, image_count, menu_open, list_keys = get_tmi_controls()
        self:AddLine("Widget: " .. tostring(control_source) .. " | LIST: " .. tostring(list_state), -55, 18)
        self:AddLine("Prefabs: " .. tostring(prefab_available) .. " (" .. tostring(prefab_count) .. ") | imagens: " .. tostring(image_count), -75, 18)
        self:AddLine("Menu aberto: " .. tostring(menu_open) .. " | campos LIST: " .. tostring(list_keys), -95, 18)
        self:AddLine("Admin: " .. tostring(net.is_admin) .. " | cliente: " .. tostring(net.is_client)
            .. " | servidor: " .. tostring(net.is_server), -135, 18)
        self:AddLine("Indicadores de metadados não comprovam compatibilidade funcional.", -175, 18)
        self:AddLine("Use Testes e o laboratório para verificar cenários específicos.", -210, 18)
    elseif self.active_tab == "conteudo" then
        self:AddLine("CATÁLOGO DE CONTEÚDO DO JOGO", 210, 27)
        local catalogs = self._content_catalogs
        if catalogs == nil then
            catalogs = {}
            self._content_catalogs = catalogs
        end
        local names = catalogs[self.content_kind]
        if names == nil then
            local source = self.content_kind == "prefabs" and rawget(DST_GLOBAL, "Prefabs") or rawget(DST_GLOBAL, "ACTIONS")
            names = {}
            if type(source) == "table" then
                for name in pairs(source) do
                    if type(name) == "string" then names[#names + 1] = name end
                end
                table.sort(names)
            end
            catalogs[self.content_kind] = names
        end
        self:AddLine((self.content_kind == "prefabs" and "Prefabs" or "Ações")
            .. ": " .. tostring(#names), 165, 20)
        local page_size = 7
        local page_count = math.max(1, math.ceil(#names / page_size))
        self.content_page = math.max(1, math.min(self.content_page, page_count))
        local first = (self.content_page - 1) * page_size + 1
        local last = math.min(#names, first + page_size - 1)
        for index = first, last do
            self:AddLine(names[index], 112 - (index - first) * 29, 17)
        end
        self:AddLine("Página " .. self.content_page .. "/" .. page_count .. " • " .. tostring(#names)
            .. " registros • somente leitura", -100, 17)

        -- Category selectors occupy their own row; pagination is separated below.
        -- This prevents the four controls from overlapping on common resolutions.
        self.content_prefabs_button = make_button(self.content, "Prefabs", -130, -145, function()
            self.content_kind = "prefabs"; self.content_page = 1; self:Refresh()
        end, 0.58)
        self.content_actions_button = make_button(self.content, "Ações", 130, -145, function()
            self.content_kind = "actions"; self.content_page = 1; self:Refresh()
        end, 0.58)
        self.content_first_button = make_button(self.content, "« Início", -300, -210, function()
            self.content_page = 1; self:Refresh()
        end, 0.58)
        self.content_prev_button = make_button(self.content, "‹ Anterior", -100, -210, function()
            self.content_page = math.max(1, self.content_page - 1); self:Refresh()
        end, 0.58)
        self.content_next_button = make_button(self.content, "Próxima ›", 100, -210, function()
            self.content_page = math.min(page_count, self.content_page + 1); self:Refresh()
        end, 0.58)
        self.content_last_button = make_button(self.content, "Fim »", 300, -210, function()
            self.content_page = page_count; self:Refresh()
        end, 0.58)
        if type(self.content_first_button.SetDisabled) == "function" then
            self.content_first_button:SetDisabled(self.content_page <= 1)
            self.content_prev_button:SetDisabled(self.content_page <= 1)
            self.content_next_button:SetDisabled(self.content_page >= page_count)
            self.content_last_button:SetDisabled(self.content_page >= page_count)
        end
    elseif self.active_tab == "receitas" then
        self:AddLine("INSPEÇÃO DE RECEITAS", 210, 27)
        if type(recipes) ~= "table" then
            self:AddLine("AllRecipes indisponível nesta sessão.", 150, 20)
        else
            local names = {}
            for name in pairs(recipes) do
                if type(name) == "string" then names[#names + 1] = name end
            end
            table.sort(names)
            self:AddLine("Receitas registradas: " .. tostring(#names), 160, 21)
            for i = 1, math.min(#names, 7) do
                self:AddLine(names[i], 115 - (i - 1) * 34, 18)
            end
            self:AddLine("Leitura somente; nenhuma receita é criada ou modificada.", -145, 18)
        end
    elseif self.active_tab == "testes" then
        self:AddLine("VERIFICAÇÕES E AUTOMAÇÃO", 210, 26)
        self.world_preflight_button = make_button(self.content, "Pré-teste mundo", -270, 265, function() self:RunScenario("world") end, 0.52)
        self.tmi_preflight_button = make_button(self.content, "Pré-teste TMI", 0, 265, function() self:RunScenario("tmi") end, 0.52)
        self.content_preflight_button = make_button(self.content, "Pré-teste conteúdo", 270, 265, function() self:RunScenario("content") end, 0.52)
        local checks = {
            { "Player carregado", player ~= nil },
            { "World carregado", world ~= nil },
            { "Simulação mestre", world ~= nil and world.ismastersim == true },
            { "SpawnPrefab acessível", type(spawn_prefab) == "function" },
            { "AllRecipes acessível", type(recipes) == "table" },
            { "Prefabs acessível", type(prefabs) == "table" },
        }
        for i, check in ipairs(checks) do
            self:AddLine((check[2] and "[OK] " or "[--] ") .. check[1], 165 - (i - 1) * 21, 16)
        end
        local ai_state = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_STATUS")
        local ai_report = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_REPORT")
        local ai_label = type(ai_state) == "table" and tostring(ai_state.status or "não verificada") or "aguardando análise"
        self:AddLine("IA embarcada: " .. ai_label, 15, 17)
        self:AddLine("Execução offline em Lua; nenhum modelo ou serviço externo é necessário.", -10, 15)
        local analysis = type(ai_report) == "table" and ai_report.analysis or nil
        local summary = type(analysis) == "table" and analysis.summary or {}
        self:AddLine("Achados: " .. tostring(summary.total or 0)
            .. " | críticos: " .. tostring(summary.critical or 0)
            .. " | erros: " .. tostring(summary.errors or 0)
            .. " | avisos: " .. tostring(summary.warnings or 0), -35, 15)
        local runtime = type(analysis) == "table" and type(analysis.registry) == "table"
            and analysis.registry.runtime_components or {}
        local runtime_label = runtime.enabled ~= true and "Desativada"
            or (runtime.available == true and "Ativa" or "Indisponível")
        local task_execution = type(ai_report) == "table" and ai_report.task_execution or {}
        self:AddLine("Investigações: " .. tostring(task_execution.executed or 0)
            .. " | componentes: " .. tostring(runtime.event_count or 0) .. " eventos"
            .. " | observador: " .. runtime_label, -55, 13)
        local findings = type(analysis) == "table" and analysis.findings or {}
        for i = 1, math.min(#findings, 5) do
            local finding = findings[i]
            self:AddLine("[" .. tostring(finding.severity) .. "] "
                .. tostring(finding.mod_name or finding.mod_id)
                .. ": " .. tostring(finding.title) .. " (" .. tostring(finding.confidence) .. ")", -82 - (i - 1) * 27, 12)
        end
        local plan = type(ai_report) == "table" and ai_report.plan or nil
        local next_task = type(ai_report) == "table" and ai_report.next_task or nil
        local last_suite_result = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_LAST_SUITE_RESULT")
        local last_suite_status = type(last_suite_result) == "table" and tostring(last_suite_result.status or "desconhecido") or "nenhum"
        self:AddLine("Próxima investigação: " .. (next_task ~= nil and tostring(next_task.kind) or "nenhuma")
            .. " | último teste: " .. last_suite_status, -210, 12)
        local selected_suites = type(ai_report) == "table" and ai_report.selected_suites or {}
        local first_suite = selected_suites[1] ~= nil and selected_suites[1].suite or nil
        local first_scenario = type(first_suite) == "table" and first_suite.scenarios[1] or nil
        self:AddLine("Suites comunitárias prontas: " .. tostring(#selected_suites), -238, 14)
        if first_suite ~= nil and first_scenario ~= nil then
            self:AddLine("Próxima suite: " .. tostring(first_suite.title), -260, 13)
            make_button(self.content, "Executar suite", 160, -280, function()
                local run_suite = rawget(DST_GLOBAL, "MODXPECTOR_RUN_AI_SUITE")
                if type(run_suite) ~= "function" then
                    self:SetStatus("Executor de suites da IA não disponível.")
                    return
                end
                self:SetStatus("Enviando suite ao Master para validação...")
                run_suite(first_suite.id, first_scenario.id, function(success, message)
                    self:Refresh()
                    self:SetStatus(message)
                    print("[ModXpector] EMBEDDED_AI_SUITE_REQUEST success=" .. tostring(success))
                end)
            end, 0.5)
        else
            self:AddLine("Nenhum mod ativo declarou uma suite compatível; só o diagnóstico passivo está disponível.", -260, 12)
        end
        make_button(self.content, "Analisar IA", -160, -280, function()
            local run = rawget(DST_GLOBAL, "MODXPECTOR_RUN_EMBEDDED_AI")
            if type(run) ~= "function" then
                self:SetStatus("Motor de IA embarcada não disponível.")
                return
            end
            self:SetStatus("Analisando inventário e evidências dos mods...")
            run(function(success, message)
                self:Refresh()
                self:SetStatus(message)
                print("[ModXpector] EMBEDDED_AI_UI_RESULT success=" .. tostring(success))
            end)
        end, 0.5)
    elseif self.active_tab == "tmi" then
        self:AddLine("INTEGRAÇÃO TOO MANY ITEMS", 210, 27)
        self:AddLine(tmi and ("Detectado: " .. tmi.name) or "Não detectado automaticamente.", 155, 22)
        self:AddLine(tmi and ("Estado no índice: " .. (tmi.enabled and "ativo" or "desativado")) or "Confira o nome exibido na lista de mods.", 115, 19)
        local net = network_info()
        self:AddLine("Menu TMI: " .. (tmi_control and type(tmi_control.Show) == "function" and "API encontrada" or "API indisponível"), 75, 19)
        self:AddLine("Admin: " .. tostring(net.is_admin) .. " | dedicado: " .. tostring(net.is_dedicated), 35, 19)
        self:AddLine("Prefabs na lista do TMI: " .. tostring(tmi_prefab_count or "indisponível"), -5, 19)
        self:AddLine("A integração só chama o botão público de abertura; não manipula itens.", -5, 18)
        if tmi_control and type(tmi_control.Show) == "function" then
            self.tmi_open_button = make_button(self.content, "Abrir menu do Too Many Items", 0, -85, function()
                local net = network_info()
                if net.is_admin == false then
                    self:SetStatus("O Too Many Items exige permissões de administrador neste mundo.")
                    return
                end
                if net.is_dedicated == true then
                    self:SetStatus("O Too Many Items não está disponível em servidor dedicado.")
                    return
                end
                local frontend = rawget(DST_GLOBAL, "TheFrontEnd")
                local hud = frontend and safe_call(frontend, "GetActiveScreen")
                if hud == nil then
                    self:SetStatus("Tela atual indisponível; não foi possível abrir o TMI.")
                    return
                end
                local was_open = tmi_control.IsTooManyItemsMenuShow == true
                self:Close()
                if was_open then
                    local ok = pcall(tmi_control.Hide, tmi_control)
                    if ok then tmi_control.IsTooManyItemsMenuShow = false end
                    self:SetStatus(ok and "Menu do TMI fechado." or "Falha ao fechar o TMI.")
                else
                    local ok = pcall(tmi_control.Show, tmi_control)
                    if ok then tmi_control.IsTooManyItemsMenuShow = true end
                    self:SetStatus(ok and "Menu do TMI aberto." or "Não foi possível abrir o menu do TMI.")
                end
            end, 0.68)
        else
            self:AddLine("Abra o TMI pelo atalho próprio dele. Nenhuma API compatível foi encontrada.", -85, 18)
        end
        make_button(self.content, "Ver lista de mods", 0, -150, function() self.active_tab = "mods"; self:Refresh() end, 0.65)
    elseif self.active_tab == "servidor" then
        self:AddLine("DIAGNÓSTICO DO SERVIDOR / MESTRE", 210, 25)
        self:AddLine("A análise principal dos mods é executada no master simulation.", 170, 18)
        self:AddLine("O relatório é solicitado por RPC e devolvido apenas ao jogador solicitante.", 140, 17)
        self.server_request_button = make_button(self.content, "Solicitar relatório do servidor", 0, 95, function()
            if type(SendModRPCToServer) ~= "function" or type(GetModRPC) ~= "function" then
                self:SetStatus("RPC indisponível nesta sessão.")
                return
            end
            local rpc = GetModRPC("dst_mod_inspector", "request_server_report")
            if rpc == nil then
                self:SetStatus("Canal RPC do Inspector indisponível.")
                return
            end
            local ok = pcall(SendModRPCToServer, rpc)
            self:SetStatus(ok and "Solicitação enviada. Aguardando resposta do mestre..." or "Falha ao solicitar relatório.")
        end, 0.68)
        local report = self.server_report or rawget(DST_GLOBAL, "DST_MOD_INSPECTOR_SERVER_REPORT")
        if type(report) == "string" and report ~= "" then
            local lines = {}
            for line in report:gmatch("[^\n]+") do lines[#lines + 1] = line end
            for i = 1, math.min(#lines, 9) do
                self:AddLine(lines[i], 45 - (i - 1) * 30, 15)
            end
            if #lines > 9 then
                self:AddLine("Relatório completo registrado no log do servidor.", -235, 16)
            end
        else
            self:AddLine("Nenhum relatório recebido nesta sessão.", 45, 18)
            self:AddLine("O mestre precisa ter carregado a versão 21.2.16 do Inspector.", 10, 17)
        end
    elseif self.active_tab == "ferramentas" then
        self:AddLine("FERRAMENTAS DE DESENVOLVIMENTO", 210, 25)
        if self.tools_mode == "detail" then
            local entity = self.selected_entity
            self:AddLine("FICHA DA ENTIDADE", 174, 22)
            self:AddLine(tostring(entity and entity.prefab or "Entidade indisponível"), 145, 18)
            local output = self.devtools_report or { "Nenhum dado de inspeção disponível." }
            for i = 1, math.min(#output, 7) do self:AddLine(output[i], 105 - (i - 1) * 27, 15) end
            make_button(self.content, "Voltar à lista", -145, -215, function()
                self.tools_mode = "entities"
                self:Refresh()
            end, 0.72)
            make_button(self.content, "Ferramentas", 145, -215, function()
                self.tools_mode = "actions"
                self:Refresh()
            end, 0.72)
        elseif self.tools_mode == "entities" then
            self:AddLine("ENTIDADES PRÓXIMAS AO PERSONAGEM", 174, 21)
            self:AddLine("Selecione uma entidade para abrir sua ficha de inspeção.", 145, 16)
            local entities = self.nearby_entities or {}
            local page_size = 8
            local page_count = math.max(1, math.ceil(#entities / page_size))
            self.entity_page = math.max(1, math.min(self.entity_page or 1, page_count))
            local first = (self.entity_page - 1) * page_size + 1
            local last = math.min(#entities, first + page_size - 1)
            if #entities == 0 then
                self:AddLine("Nenhuma entidade encontrada no raio de 16 unidades.", 85, 18)
                self:AddLine("Use Atualizar lista para procurar novamente.", 55, 16)
            else
                for index = first, last do
                    local entity = entities[index]
                    local prefab = tostring(entity.prefab or "entidade")
                    local display_name = safe_call(entity, "GetDisplayName")
                    local label = display_name and (tostring(display_name) .. "  [" .. prefab .. "]") or prefab
                    if #label > 30 then label = string.sub(label, 1, 27) .. "..." end
                    local column = (index - first) % 2
                    local row = math.floor((index - first) / 2)
                    make_button(self.content, label, column == 0 and -145 or 145, 105 - row * 62, function()
                        if entity ~= nil and (type(entity.IsValid) ~= "function" or safe_call(entity, "IsValid") ~= false) then
                            self.devtools_report = Devtools.InspectEntity(entity)
                            self.selected_entity = entity
                            self.tools_mode = "detail"
                            Devtools.Record("entity_inspect", tostring(entity.prefab or "unknown"), DST_GLOBAL)
                            self:Refresh()
                            self:SetStatus("Entidade inspecionada: " .. tostring(entity.prefab or "entidade"))
                        else
                            self:SetStatus("A entidade não está mais disponível. Atualize a lista.")
                        end
                    end, 0.72)
                end
            end
            self:AddLine("Página " .. self.entity_page .. "/" .. page_count .. " • raio de 16", -155, 16)
            make_button(self.content, "Anterior", -270, -215, function()
                self.entity_page = math.max(1, self.entity_page - 1)
                self:Refresh()
            end, 0.5)
            make_button(self.content, "Próxima", -90, -215, function()
                self.entity_page = math.min(page_count, self.entity_page + 1)
                self:Refresh()
            end, 0.5)
            make_button(self.content, "Atualizar", 90, -215, function()
                self:RefreshNearbyEntities()
                self:Refresh()
                self:SetStatus("Lista de entidades próximas atualizada.")
            end, 0.5)
            make_button(self.content, "Voltar", 270, -215, function()
                self.tools_mode = "actions"
                self:Refresh()
            end, 0.5)
        else
            local output = self.devtools_report or { "Escolha uma ferramenta abaixo." }
            for i = 1, math.min(#output, 3) do self:AddLine(output[i], 165 - (i - 1) * 24, 15) end
            -- Two-column grid with generous spacing; long labels fit inside each Redux button.
            make_button(self.content, "Entidades próximas", -145, 65, function()
                self:RefreshNearbyEntities()
                self.tools_mode = "entities"
                self.entity_page = 1
                self:Refresh()
                self:SetStatus("Selecione uma entidade encontrada perto do personagem.")
            end, 0.72)
            make_button(self.content, "Inspecionar sob cursor", 145, 65, function()
                local input = rawget(DST_GLOBAL, "TheInput")
                local entity = input and safe_call(input, "GetWorldEntityUnderMouse")
                self.devtools_report = Devtools.InspectEntity(entity)
                Devtools.Record("entity_inspect_cursor", entity and tostring(entity.prefab) or "nenhuma entidade", DST_GLOBAL)
                self:Refresh()
                self:SetStatus(entity and "Inspeção da entidade concluída." or "Nenhuma entidade sob o cursor.")
            end, 0.72)
            make_button(self.content, "Analisar dependências", -145, -5, function()
                local analysis = Devtools.AnalyzeMods(DST_GLOBAL)
                self.devtools_report = analysis.lines
                Devtools.Record("mod_analysis", tostring(#analysis.warnings) .. " aviso(s)", DST_GLOBAL)
                self:Refresh()
                self:SetStatus("Análise de metadados concluída; não confirma conflitos de runtime.")
            end, 0.72)
            make_button(self.content, "Capturar snapshot A", 145, -5, function()
                self.mod_snapshot_a = Devtools.SnapshotMods(DST_GLOBAL)
                self.devtools_report = { self.mod_snapshot_a and "Snapshot A capturado." or "Falha: KnownModIndex indisponível." }
                self:Refresh()
            end, 0.72)
            make_button(self.content, "Capturar snapshot B", -145, -75, function()
                self.mod_snapshot_b = Devtools.SnapshotMods(DST_GLOBAL)
                self.devtools_report = { self.mod_snapshot_b and "Snapshot B capturado." or "Falha: KnownModIndex indisponível." }
                self:Refresh()
            end, 0.72)
            make_button(self.content, "Comparar snapshots", 145, -75, function()
                self.devtools_report = Devtools.CompareSnapshots(self.mod_snapshot_a, self.mod_snapshot_b)
                Devtools.Record("snapshot_compare", "comparação A/B executada", DST_GLOBAL)
                self:Refresh()
            end, 0.72)
            make_button(self.content, "Exportar sessão", -145, -145, function()
                local journal, count = Devtools.GetSessionReport()
                write_export_block("CLIENT_SESSION_JOURNAL", journal)
                self.devtools_report = { "Diário marcado no client_log.txt.", "Eventos registrados: " .. tostring(count), "Use IA / Testes para executar a análise offline e consultar os achados." }
                self:Refresh()
                self:SetStatus("Diário da sessão exportado para o log.")
            end, 0.72)
            make_button(self.content, "Gerar relatório geral", 145, -145, function()
                local mods, tmi, tmi_control, tmi_data, tmi_prefab_count,
                    tmi_control_source, tmi_list_state, tmi_prefab_list_available,
                    tmi_show_image_count, tmi_menu_open, tmi_list_keys, tmi_status = build_report()
                local net = network_info()
                local report_lines = {
                    "DST MOD INSPECTOR — RELATÓRIO GERAL",
                    "Version: " .. VERSION,
                    "Known mods: " .. tostring(type(mods) == "table" and #mods or 0),
                    "TMI detected: " .. tostring(tmi ~= nil),
                    "TMI family: " .. tostring(type(tmi) == "table" and (tmi.family_name or tmi.name) or "not detected"),
                    "TMI version: " .. tostring(type(tmi) == "table" and tmi.version or "not detected"),
                    "TMI workshop id: " .. tostring(type(tmi) == "table" and tmi.id or "not detected"),
                    "TMI enabled: " .. tostring(type(tmi) == "table" and tmi.enabled == true),
                    "TMI client-only metadata: " .. tostring(type(tmi) == "table" and tmi.client_only == true),
                    "TMI documented open key: " .. tostring(type(tmi) == "table" and tmi.tmi_open_key or "not verified for this variant"),
                    "TMI admin-gated documented: " .. tostring(type(tmi) == "table" and tmi.tmi_admin_gated_documented == true),
                    "TMI controls available (optional diagnostic): " .. tostring(type(tmi_control) == "table"),
                    "TMI controls source: " .. tostring(tmi_control_source),
                    "TMI LIST state: " .. tostring(tmi_list_state),
                    "TMI integration state: " .. tostring(tmi_status),
                    "TMI prefab list available: " .. tostring(tmi_prefab_list_available),
                    "TMI show-image entries: " .. tostring(tmi_show_image_count),
                    "TMI menu open: " .. tostring(tmi_menu_open),
                    "TMI LIST fields: " .. tostring(tmi_list_keys),
                    "TMI LIST shape: " .. TMIProbe.GetListShape(tmi_data),
                    "TMI data available: " .. tostring(type(tmi_data) == "table"),
                    "TMI Show method: " .. tostring(type(tmi_control) == "table" and type(tmi_control.Show) == "function"),
                    "TMI Hide method: " .. tostring(type(tmi_control) == "table" and type(tmi_control.Hide) == "function"),
                    "TMI prefab entries: " .. tostring(tmi_prefab_count or "unavailable"),
                    "Client: " .. tostring(net.is_client),
                    "Server: " .. tostring(net.is_server),
                    "Admin: " .. tostring(net.is_admin),
                    "TMI visibility rule: client-only; menu hidden from non-admin clients",
                    "Dedicated: " .. tostring(net.is_dedicated),
                    "Enabled mods:"
                }
                local enabled_count = 0
                if type(mods) == "table" then
                    for _, mod in ipairs(mods) do
                        if mod.enabled then
                            enabled_count = enabled_count + 1
                            report_lines[#report_lines + 1] = "- " .. tostring(mod.name)
                                .. " | " .. tostring(mod.id)
                                .. " | API " .. tostring(mod.api_version)
                                .. " | version " .. tostring(mod.version)
                        end
                    end
                else
                    report_lines[#report_lines + 1] = "Mod inventory unavailable."
                end
                table.insert(report_lines, 4, "Enabled mods count: " .. tostring(enabled_count))
                if tmi ~= nil then
                    table.insert(report_lines, 6, "TMI mod: " .. tostring(tmi.name) .. " | " .. tostring(tmi.id))
                end
                local config = self.runtime_config or {}
                local config_key = tostring(config.open_key or "KEY_F6")
                report_lines[#report_lines + 1] = "CONFIGURATION"
                report_lines[#report_lines + 1] = "open_key=" .. config_key .. " (source=local_client)"
                report_lines[#report_lines + 1] = "show_debug_info=" .. tostring(config.show_debug_info == true) .. " (source=local_client)"
                report_lines[#report_lines + 1] = "test_mode=" .. tostring(config.test_mode == true) .. " (source=server)"
                report_lines[#report_lines + 1] = "max_spawn_count=" .. tostring(config.max_spawn_count or 10) .. " (source=server)"
                local report = table.concat(report_lines, "\n")
                local journal, event_count = Devtools.GetSessionReport()
                local server_report = tostring(self.server_report or "")
                write_export_block("CLIENT_FULL_REPORT", report)
                write_export_block("CLIENT_SESSION_JOURNAL", journal or "")
                local server_status = "NOT_CAPTURED"
                if server_report ~= "" then
                    write_export_block("SERVER_DIAGNOSTICS", server_report)
                    server_status = "CAPTURED"
                end
                local checklist = table.concat({
                    "client_full_report=CAPTURED",
                    "client_session_journal=CAPTURED",
                    "server_diagnostics=" .. server_status,
                    "enabled_mod_count=" .. tostring(enabled_count),
                    "session_event_count=" .. tostring(event_count or 0),
                    "note=NOT_CAPTURED means the server report was not requested or did not return"
                }, "\n")
                write_export_block("REPORT_CHECKLIST", checklist)
                self.devtools_report = {
                    "Pacote de diagnóstico marcado no client_log.txt.",
                    "Mods ativos: " .. tostring(enabled_count),
                    "Eventos da sessão: " .. tostring(event_count or 0),
                    "Relatório do servidor: " .. (server_status == "CAPTURED" and "incluído" or "não capturado"),
                    "Peça o relatório do servidor antes de exportar para incluir os dados do master."
                }
                self:Refresh()
                self:SetStatus("Relatório geral exportado para o log. Use o exportador da pasta tools do mod.")
            end, 0.72)
            make_button(self.content, "Atualizar dados", 0, -215, function()
                self:Refresh()
                self:SetStatus("Dados atualizados.")
            end, 0.72)
        end
    elseif self.active_tab == "config" then
        local config = self.runtime_config or {}
        local key_name = tostring(config.open_key or "KEY_F6")
        key_name = string.gsub(key_name, "^KEY_", "")
        self:AddLine("CONFIGURAÇÕES ATIVAS DO MOD", 210, 25)
        self:AddLine("Abrir/fechar painel: " .. key_name, 165, 21)
        self:AddLine("Informações técnicas: " .. (config.show_debug_info and "Ativadas" or "Desativadas"), 125, 19)
        self:AddLine("IA embarcada: incluída no próprio ModXpector", 90, 19)
        self:AddLine("Modo de testes controlados: " .. (config.test_mode and "Ativado" or "Desativado"), 55, 19)
        self:AddLine("Observação de componentes em runtime: "
            .. (config.collect_runtime_components and "Ativada" or "Desativada"), -15, 18)
        local ai_state = rawget(DST_GLOBAL, "MODXPECTOR_EMBEDDED_AI_STATUS")
        self:AddLine("Estado da IA: " .. (type(ai_state) == "table" and tostring(ai_state.status or "não verificada") or "aguardando análise"), 20, 18)
        self:AddLine("Limite de geração por ação: " .. tostring(config.max_spawn_count or 10), -45, 18)
        self:AddLine("Entrada ModXpector no menu de pausa: registrada pelo jogo", -80, 17)
        self:AddLine("Para editar: menu principal > Mods > ModXpector > Configurar", -115, 17)
        self:AddLine("A análise principal funciona offline, sem Ollama, Python ou servidor.", -150, 15)
        self:AddLine("A observação de componentes é opcional, limitada e somente leitura.", -175, 14)
        make_button(self.content, "Executar análise da IA embarcada", 0, -215, function()
            local run = rawget(DST_GLOBAL, "MODXPECTOR_RUN_EMBEDDED_AI")
            if type(run) ~= "function" then
                self:SetStatus("Motor de IA embarcada não disponível.")
                return
            end
            self:SetStatus("Atualizando diagnóstico local...")
            run(function(success, message)
                self:Refresh()
                self:SetStatus(message)
                print("[ModXpector] EMBEDDED_AI_CONFIG_RESULT success=" .. tostring(success))
            end)
        end, 0.72)
    else
        self:AddLine("AJUDA E LIMITES", 210, 27)
        self:AddLine("Atalho: configurado nas opções do mod (padrão F6).", 150, 20)
        self:AddLine("ESC fecha o painel. Clique nas abas para navegar.", 110, 20)
        self:AddLine("O painel é local; o diagnóstico principal também roda no servidor/mestre.", 70, 20)
        self:AddLine("Testes simulados no laboratório não substituem o teste no DST real.", 30, 20)
        self:AddLine("Relatórios são separados em DST Mod Inspector dentro da pasta de logs.", -10, 20)
        self:AddLine("Use IA / Testes para executar a análise offline e ver os achados.", -40, 18)
    end
end

function InspectorScreen:OnControl(control, down)
    if InspectorScreen._base.OnControl(self, control, down) then return true end
    if not down and control == CONTROL_CANCEL then self:Close(); return true end
    return false
end

return InspectorScreen
