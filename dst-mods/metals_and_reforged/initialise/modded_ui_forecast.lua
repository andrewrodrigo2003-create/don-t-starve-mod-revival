-- Metals and More Reforged
-- Extensao aditiva do widget de container: texto dinamico e preview visual da forja.
--
-- A previsao e calculada no cliente a partir das replicas dos slots e das tabelas
-- estaticas de metalurgia. O servidor continua autoritativo para o resultado
-- sorteado, publicado pela netvar mam_plan. Nenhum RPC e enviado por item movido.

local GLOBAL = GLOBAL
local require = GLOBAL.require

local MAMLog = require("mam/log")
local MAMForecast = require("mam/forecast")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local Text = require("widgets/text")

local DIRTY_EVENT = "mamplandirty"
local FORGE_PREFAB = "metal_smelter"
local FONT = GLOBAL.BODYTEXTFONT or GLOBAL.UIFONT or GLOBAL.NUMBERFONT
local QUANTITY_FONT = GLOBAL.NUMBERFONT or "stint-ucr"

local unpack = GLOBAL.unpack or unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

local function unpack_results(results)
    return unpack(results, 1, results.n)
end

local function button_info(self)
    if self.container == nil or self.container.replica == nil
        or self.container.replica.container == nil then
        return nil
    end

    local ok, widget = MAMLog.Try("forecast:GetWidget", self.container.replica.container.GetWidget,
        self.container.replica.container)
    if not ok or widget == nil or widget.buttoninfo == nil then
        return nil
    end
    return widget.buttoninfo
end

local function update_text(self)
    if self.button == nil then
        return
    end

    local info = button_info(self)
    if info == nil or info.textfn == nil then
        return
    end

    local ok, text = MAMLog.Try("forecast:textfn", info.textfn, self.container, self)
    if ok and type(text) == "string" and text ~= self.mam_last_button_text then
        self.mam_last_button_text = text
        self.button:SetText(text)
    end
end

local function make_preview(self)
    if self.mam_forge_preview ~= nil or self.container == nil
        or self.container.prefab ~= FORGE_PREFAB then
        return
    end

    local panel = self:AddChild(Widget("MAMForgePreview"))
    panel:SetPosition(GLOBAL.Vector3(-270, 0, 0))
    -- Keep the preview clear of the smelter input slots; scale the complete HUD
    -- (frame, icon, labels and quantity) by the requested 20%.
    panel:SetScale(1.2)

    panel.header = panel:AddChild(Text(FONT, 22, "FORGE PREVIEW"))
    panel.header:SetPosition(0, 91, 0)
    panel.header:SetColour(1, 0.9, 0.72, 1)

    panel.slotbg = panel:AddChild(Image("images/hud.xml", "inv_slot.tex"))
    panel.slotbg:SetPosition(-48, 22, 0)
    panel.slotbg:SetScale(1.8)

    panel.icon = panel:AddChild(Image())
    panel.icon:SetPosition(-48, 22, 0)
    panel.icon:SetScale(1.45)
    panel.icon:Hide()

    -- O nome faz parte da imagem: fica sobreposto no topo do proprio icone.
    panel.name = panel:AddChild(Text(FONT, 17, "Add materials"))
    panel.name:SetPosition(-48, 54, 0)
    panel.name:SetHAlign(GLOBAL.ANCHOR_MIDDLE)
    panel.name:SetVAlign(GLOBAL.ANCHOR_MIDDLE)
    panel.name:SetRegionSize(104, 30)
    panel.name:EnableWordWrap(true)
    panel.name:SetColour(1, 0.96, 0.84, 1)

    -- Mesmo padrao visual do ItemTile vanilla: NUMBERFONT, tamanho 42 e
    -- limite 999+. O contador fica dentro do canto inferior direito do icone.
    panel.quantity = panel:AddChild(Text(QUANTITY_FONT, 42, ""))
    panel.quantity:SetSize(42)
    panel.quantity:SetPosition(-20, -5, 0)
    panel.quantity:SetHAlign(GLOBAL.ANCHOR_RIGHT)
    panel.quantity:SetRegionSize(48, 48)
    panel.quantity:SetColour(1, 1, 1, 1)

    panel.details = panel:AddChild(Text(FONT, 18, "The forge result will appear here."))
    panel.details:SetPosition(0, -55, 0)
    panel.details:SetRegionSize(230, 76)
    panel.details:EnableWordWrap(true)
    panel.details:SetHAlign(GLOBAL.ANCHOR_MIDDLE)
    panel.details:SetVAlign(GLOBAL.ANCHOR_MIDDLE)
    panel.details:SetColour(1, 0.94, 0.8, 1)

    self.mam_forge_preview = panel
end

local function preview_data(plan)
    if plan == nil then
        return nil, nil, "Preview unavailable", "The recipe forecast could not be calculated."
    end

    local phase = plan.phase or plan.state
    if phase == "empty" then
        return nil, nil, "Add materials", "Insert metal ingredients to preview the result."
    elseif phase == "invalid" or plan.state == "invalid" then
        return nil, nil, "No valid result", "This combination has no registered smelting recipe."
    elseif phase == "error" then
        return nil, nil, "Preview unavailable", "The recipe forecast failed; check the log."
    elseif phase == "ambiguous" then
        local names = {}
        for i, prefab in ipairs(plan.possibilities or {}) do
            if i > 4 then
                names[#names + 1] = "..."
                break
            end
            names[#names + 1] = MAMForecast.product_name(prefab) or prefab
        end
        return nil, nil, "Possible results", table.concat(names, " / ")
    elseif plan.ambiguous and plan.outcomes ~= nil and #plan.outcomes > 1 then
        local outcomes = {}
        for i, outcome in ipairs(plan.outcomes) do
            if i > 4 then
                outcomes[#outcomes + 1] = "..."
                break
            end
            local outcome_name = MAMForecast.product_name(outcome.product) or outcome.product
            outcomes[#outcomes + 1] = tostring(outcome.count or 1) .. " x " .. outcome_name
        end
        return nil, nil, "Possible results", table.concat(outcomes, " / ")
    end

    local product = plan.product
    if product == nil then
        return nil, nil, "No result", "The forge has not selected a product."
    end

    local name = MAMForecast.product_name(product) or product
    local count = math.max(1, tonumber(plan.count) or 1)
    local details

    if phase == "smelting" then
        details = "Currently smelting"
    elseif phase == "harvest" then
        details = "Ready to collect"
    else
        details = "Predicted output"
    end

    return product, count, name, details
end

local MAM_INVENTORY_PRODUCTS = {
    copper_ore = true, iron_ore = true,
    copper_ingot = true, iron_ingot = true, bronze_ingot = true,
    gold_ingot = true, moonglass_ingot = true, adamantium_ingot = true,
    junk_dust = true, copper_dust = true, iron_dust = true, gold_dust = true,
}

local function get_product_atlas(product, image_name)
    -- Custom MAM products each own a dedicated atlas; GetInventoryItemAtlas
    -- only knows them when the global lookup has been registered.
    if MAM_INVENTORY_PRODUCTS[product] then
        return "images/inventoryimages/" .. product .. ".xml"
    end
    local ok, atlas = pcall(GLOBAL.GetInventoryItemAtlas, image_name)
    return ok and atlas or nil
end

local function update_preview(self)
    local panel = self.mam_forge_preview
    if panel == nil or self.container == nil then
        return
    end

    local ok, plan = MAMLog.Try("forge-preview:plan", MAMForecast.plan, self.container)
    if not ok then
        plan = nil
    end

    local product, count, name, details = preview_data(plan)
    local quantity = count ~= nil and (count > 999 and "999+" or tostring(count)) or ""
    local fingerprint = table.concat({
        tostring(product or ""),
        tostring(count or ""),
        tostring(name or ""),
        tostring(details or ""),
        quantity,
    }, "|")

    if fingerprint == self.mam_forge_preview_fingerprint then
        return
    end
    self.mam_forge_preview_fingerprint = fingerprint

    panel.name:SetString(name or "Preview unavailable")
    panel.quantity:SetString(quantity)
    panel.quantity:SetSize(count ~= nil and count > 999 and 36 or 42)
    panel.quantity:SetPosition(-20, -5, 0)
    panel.details:SetString(details or "")

    if product ~= nil then
        local image_name = product .. ".tex"
        local atlas = get_product_atlas(product, image_name)
        if atlas ~= nil then
            local texture_ok = pcall(panel.icon.SetTexture, panel.icon, atlas, image_name)
            if texture_ok then
                panel.icon:Show()
            else
                panel.icon:Hide()
            end
        else
            panel.icon:Hide()
        end
    else
        panel.icon:Hide()
    end
end

local function update_container(self)
    update_text(self)
    update_preview(self)
end

AddClassPostConstruct("widgets/containerwidget", function(ContainerWidget)
    if ContainerWidget == nil or ContainerWidget.mam_textfn_supported then
        return
    end

    ContainerWidget.mam_update_text = update_text
    ContainerWidget.mam_update_preview = update_preview

    ---------------------------------------------------------------------
    -- Open: instala o listener de plano replicado e cria o preview da forja
    ---------------------------------------------------------------------
    local oldOpen = ContainerWidget.Open
    function ContainerWidget:Open(container, doer, ...)
        local results = pack(oldOpen(self, container, doer, ...))

        if container ~= nil and self.mam_plan_listener == nil then
            self.mam_plan_listener = function()
                update_container(self)
            end
            container:ListenForEvent(DIRTY_EVENT, self.mam_plan_listener)
        end

        self.mam_last_button_text = nil
        make_preview(self)
        update_container(self)

        return unpack_results(results)
    end

    ---------------------------------------------------------------------
    -- Refresh / itemget / itemlose: recalcula apenas quando a carga muda
    ---------------------------------------------------------------------
    for _, name in ipairs({ "Refresh", "OnItemGet", "OnItemLose" }) do
        local old = ContainerWidget[name]
        if type(old) == "function" then
            ContainerWidget[name] = function(self, ...)
                local results = pack(old(self, ...))
                MAMLog.Try("forecast:" .. name, update_container, self)
                return unpack_results(results)
            end
        end
    end

    ---------------------------------------------------------------------
    -- Close: remove listeners e widgets para nao reter referencias antigas
    ---------------------------------------------------------------------
    local oldClose = ContainerWidget.Close
    function ContainerWidget:Close(...)
        if self.mam_plan_listener ~= nil and self.container ~= nil and self.container:IsValid() then
            self.container:RemoveEventCallback(DIRTY_EVENT, self.mam_plan_listener)
        end
        self.mam_plan_listener = nil
        self.mam_last_button_text = nil
        self.mam_forge_preview_fingerprint = nil

        if self.mam_forge_preview ~= nil then
            self.mam_forge_preview:Kill()
            self.mam_forge_preview = nil
        end

        return oldClose(self, ...)
    end

    ContainerWidget.mam_textfn_supported = true
end)
