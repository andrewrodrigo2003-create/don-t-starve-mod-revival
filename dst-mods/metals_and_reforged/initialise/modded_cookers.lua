local RPC = GLOBAL.RPC
local TUNING = GLOBAL.TUNING
local require = GLOBAL.require
local Vector3 = GLOBAL.Vector3
local ACTIONS = GLOBAL.ACTIONS
--local cooking = require("cooking")
local smeltable = require("smelting")
local containers = require("containers")
local MAMConfig = require("mam/config")
local MAMForecast = require("mam/forecast")
local BufferedAction = GLOBAL.BufferedAction
local SendRPCToServer = GLOBAL.SendRPCToServer

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smelter

local function CreateSmelterWidget()
	local params = {}

	-- Aceita pilha quando o lote esta ligado: sem isso e impossivel carregar
	-- mais de 4 minerais, e a fundicao em lote nao tem o que multiplicar.
	local accepts_stacks = MAMConfig.on("mam_batch")

	params.smelter =
	{
	widget =
    {
        slotpos =
        {
            Vector3(0, 64 + 32, 0),
            Vector3(0, 24, 0),
            Vector3(0, -(32 + 16), 0),
            Vector3(0, -(64 + 32 + 16 + 8), 0),
        },
        animbank = "new_cooker_ui_1x4",
        animbuild = "new_cooker_ui_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100,
        buttoninfo =
        {
            text = "Smelt",
            position = Vector3(0, -180, 0),
            -- textfn: campo nosso (ver modded_ui_forecast.lua). Devolve a
            -- previsao da carga enquanto o jogador monta a mistura.
            textfn = MAMForecast.button_text,
        }
    },
    acceptsstacks = accepts_stacks,
    type = "cooker",
	}

	containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, params.smelter.widget.slotpos ~= nil and #params.smelter.widget.slotpos or 0)

	local old_widgetsetup = containers.widgetsetup

	-- Assinatura vanilla: widgetsetup(container, prefab, data). `data` e' a tabela de
	-- params que um mod (ou o proprio prefab) pode injetar na chamada; quando ela vem
	-- preenchida, nao e' nosso caso e o caminho e' a funcao anterior, para nao perder
	-- o payload de outro mod. `...` e' reencaminhado porque Uncompromising Mode Beta
	-- (init/init_containers.lua:690-706) tambem embrulha esta funcao.
	function containers.widgetsetup(container, prefab, data, ...)
		local pref = prefab or container.inst.prefab

		if pref == "smelter" and data == nil then
			local t = params[pref]

			if t ~= nil then
				for k, v in pairs(t) do
					container[k] = v
				end
			container:SetNumSlots(container.widget.slotpos ~= nil and #container.widget.slotpos or 0)
			end
		else
			return old_widgetsetup(container, prefab, data, ...)
		end
	end

	function params.smelter.widget.buttoninfo.fn(inst, doer)
		if inst.components.container ~= nil then
			BufferedAction(inst.components.container.opener, inst, ACTIONS.SMELT):Do()
		elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
			SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.SMELT.code, inst, ACTIONS.SMELT.mod_name)
		end
	end

	function params.smelter.itemtestfn(container, item, slot)
		return (smeltable.IsSmelterIngredient(item.prefab))
	end

	-- Original: exigia os 4 slots cheios (IsFull). Com lote e previsao, o que
	-- vale e "essa carga produz algo?". Com forecast desligado, volta a IsFull.
	function params.smelter.widget.buttoninfo.validfn(inst)
		return MAMForecast.can_start(inst)
	end
end

CreateSmelterWidget()
