-- Metals and More - Reworked & Fixed
-- Extensao aditiva do widget de container: suporte a buttoninfo.textfn.
--
-- O vanilla so le buttoninfo.text uma vez, em Open(). Para a fornalha mostrar
-- o que a carga VIRAR antes de o jogador apertar o botao, o texto precisa
-- acompanhar itemget/itemlose/refresh e o plano replicado do servidor.
--
-- Nada aqui muda o comportamento de containers que nao definem textfn: e um
-- campo novo, opcional, lido so quando existe.

-- Arquivo carregado via modimport: o ambiente do mod expoe GLOBAL, mas nao _G.
local GLOBAL = GLOBAL
local require = GLOBAL.require

local MAMLog = require("mam/log")

local DIRTY_EVENT = "mamplandirty"

AddClassPostConstruct("widgets/containerwidget", function(ContainerWidget)
    if ContainerWidget == nil or ContainerWidget.mam_textfn_supported then
        return
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

    ContainerWidget.mam_update_text = update_text

    ---------------------------------------------------------------------
    -- Open: registra o evento de plano replicado e pintou o texto inicial
    ---------------------------------------------------------------------
    local oldOpen = ContainerWidget.Open
    function ContainerWidget:Open(container, doer)
        local ret = oldOpen(self, container, doer)

        if container ~= nil and self.mam_plan_listener == nil then
            self.mam_plan_listener = function()
                update_text(self)
            end
            container:ListenForEvent(DIRTY_EVENT, self.mam_plan_listener)
        end

        self.mam_last_button_text = nil
        update_text(self)

        return ret
    end

    ---------------------------------------------------------------------
    -- Refresh / itemget / itemlose: reavaliam o texto
    ---------------------------------------------------------------------
    for _, name in ipairs({ "Refresh", "OnItemGet", "OnItemLose" }) do
        local old = ContainerWidget[name]
        if type(old) == "function" then
            ContainerWidget[name] = function(self, ...)
                local ret, ret2 = old(self, ...)
                MAMLog.Try("forecast:" .. name, update_text, self)
                return ret, ret2
            end
        end
    end

    ---------------------------------------------------------------------
    -- Close: remove o listener, para nao vazar referencia entre telas
    ---------------------------------------------------------------------
    local oldClose = ContainerWidget.Close
    function ContainerWidget:Close(...)
        if self.mam_plan_listener ~= nil and self.container ~= nil and self.container:IsValid() then
            self.container:RemoveEventCallback(DIRTY_EVENT, self.mam_plan_listener)
        end
        self.mam_plan_listener = nil
        self.mam_last_button_text = nil

        return oldClose(self, ...)
    end

    ContainerWidget.mam_textfn_supported = true
end)
