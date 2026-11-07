-- Metals and More - Reworked & Fixed
-- Previsao de fundicao (forecast) para a interface da fornalha.
--
-- Por que roda no cliente: o botao da UI precisa responder enquanto o jogador
-- ainda esta arrastando mineral para dentro, e um RPC por movimentacao de item
-- seria caro e ia divergir em MP. As tabelas de smelting sao dados estaticos
-- identicos dos dois lados, entao o cliente pode calcular a previsao sozinho.
--
-- O que o servidor manda de verdade e so o resultado JA SORTEADO (produto,
-- quantidade, fase) pela net var mam_plan do prefab metal_smelter. Quando ela
-- existe, ela manda na mensagem; antes de comecar, usamos a previsao local.

local GLOBAL = rawget(_G, "GLOBAL") or _G

local smelting = require("smelting")
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")

local MAMForecast = {}

local function product_name(prefab)
    if prefab == nil then
        return nil
    end
    local strings = GLOBAL.STRINGS
    if strings ~= nil and strings.NAMES ~= nil then
        local n = strings.NAMES[string.upper(prefab)]
        if type(n) == "string" then
            return n
        end
    end
    return prefab
end
MAMForecast.product_name = product_name

--- Conteudo atual do container, lido pela replica (funciona em SP e em MP,
--- porque a replica proxia o componente quando este servidor).
function MAMForecast.container_items(inst)
    local items = {}
    if inst == nil or not inst:IsValid() then
        return items
    end

    local replica = inst.replica ~= nil and inst.replica.container or nil
    if replica == nil then
        return items
    end

    local ok, contents = MAMLog.Try("forecast.GetItems", replica.GetItems, replica)
    if not ok or contents == nil then
        return items
    end

    local gathered = {}
    for slot, item in pairs(contents) do
        if type(slot) == "number" and item ~= nil and item:IsValid() then
            local count = 1
            if item.components.stackable ~= nil and item.components.stackable:IsStack() then
                count = item.components.stackable:StackSize()
            end
            gathered[slot] = { slot = slot, prefab = item.prefab, count = count }
        end
    end

    -- Ordem de slot deterministica: o consumo do lote depende dela.
    local slots = {}
    for slot in pairs(gathered) do
        table.insert(slots, slot)
    end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        table.insert(items, gathered[slot])
    end
    return items
end

--- Protocolo da net var mam_plan:
---   "c|batch|cap|crescimento p|produto|quantidade|fase"
--- A primeira metade e a configuracao de SIM do servidor; a segunda, o ultimo
--- plano sorteado por ele. Qualquer uma das duas pode faltar em string antiga
--- ou truncada, e nesse caso caimos no valor local do cliente.
local function parse_net_plan(inst)
    if inst.mam_plan == nil then
        return nil
    end
    local raw = inst.mam_plan()
    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local out = {}

    local batch, cap, growth = string.match(raw, "c|(%d+)|(%d+)|(%d+)")
    if batch ~= nil then
        out.cfg = {
            batch = tonumber(batch) > 0,
            cap = tonumber(cap),
            batch_time = tonumber(growth),
        }
    end

    local product, count, phase = string.match(raw, "p|([%w_]*)|(%d+)|(%a+)")
    if product ~= nil then
        out.product = product ~= "" and product or nil
        out.count = tonumber(count) or 1
        out.phase = phase
    end

    if out.cfg == nil and out.product == nil then
        return nil
    end
    return out
end
MAMForecast.parse_net_plan = parse_net_plan

--- Plano atual para a UI: o sorteado pelo servidor quando ha fundicao em
--- curso ou produto pronto; previsao local quando ainda so tem carga.
function MAMForecast.plan(inst)
    local net = parse_net_plan(inst)
    if net ~= nil and (net.phase == "smelting" or net.phase == "harvest") then
        net.source = "server"
        return net
    end

    local items = MAMForecast.container_items(inst)
    if #items == 0 then
        return { phase = "empty", source = "forecast" }
    end

    -- Valores de lote do servidor, quando publicados: evitam que o cliente
    -- anuncie uma quantidade que o servidor nao vai produzir.
    local opts = net ~= nil and net.cfg or nil

    local ok, plan = MAMLog.Try("forecast.ForecastSmelterPlan",
        smelting.ForecastSmelterPlan, inst.prefab, items, opts)
    if not ok or plan == nil then
        return { phase = "error", source = "forecast" }
    end
    plan.source = "forecast"
    plan.phase = plan.state
    return plan
end

function MAMForecast.can_start(inst)
    if not MAMConfig.on("mam_forecast") then
        -- Sem forecast, mantem a regra original: so pode comecar com tudo cheio.
        local replica = inst.replica ~= nil and inst.replica.container or nil
        return replica ~= nil and replica:IsFull()
    end

    local net = parse_net_plan(inst)
    if net ~= nil and (net.phase == "smelting" or net.phase == "harvest") then
        return false
    end

    local plan = MAMForecast.plan(inst)
    return plan ~= nil and plan.state == "ready" and plan.product ~= nil
end

local function join(list, sep)
    local out = {}
    for i = 1, #list do
        out[i] = product_name(list[i])
    end
    return table.concat(out, sep)
end

--- Texto curto e fixo para o botao da fornalha.
function MAMForecast.button_text(inst)
    if not MAMConfig.on("mam_forecast") then
        return "Smelt"
    end

    local plan = MAMForecast.plan(inst)
    if plan == nil then
        return "Smelt"
    end

    if plan.phase == "smelting" then
        return "Smelting"
    elseif plan.phase == "harvest" then
        if (plan.count or 1) > 1 then
            return "Harvest " .. tostring(plan.count)
        end
        return "Harvest"
    elseif plan.phase == "empty" then
        return "Smelt"
    elseif plan.state == "invalid" or plan.phase == "invalid" then
        return "No match"
    elseif plan.phase == "ambiguous" then
        return "Mixed load"
    end

    if plan.ambiguous and plan.possibilities ~= nil and #plan.possibilities > 1 then
        return "Makes " .. join(plan.possibilities, " / ")
    end

    local name = product_name(plan.product)
    if name == nil then
        return "Smelt"
    end
    if (plan.count or 1) > 1 then
        return "Makes " .. tostring(plan.count) .. " " .. name
    end
    return "Makes " .. name
end

--- Linha longa de detalhe, para o tooltip do botao e para o inspectable.
function MAMForecast.detail_text(inst)
    local plan = MAMForecast.plan(inst)
    if plan == nil then
        return nil
    end

    if plan.phase == "empty" then
        return "Add ore, dust, shards or scrap to see what it becomes."
    elseif plan.phase == "invalid" then
        return "This mixture has no smelting result."
    elseif plan.phase == "ambiguous" then
        return "This mixture could yield more than one alloy. Sort the load to predict it."
    end

    local lines = {}
    if plan.source == "server" then
        table.insert(lines, (plan.phase == "harvest" and "Ready: " or "Smelting: ")
            .. tostring(plan.count or 1) .. " " .. (product_name(plan.product) or "?"))
    else
        table.insert(lines, "Will produce: " .. tostring(plan.count or 1) .. " " .. (product_name(plan.product) or "?"))
        if plan.ambiguous and plan.possibilities ~= nil and #plan.possibilities > 1 then
            table.insert(lines, "Or one of: " .. join(plan.possibilities, ", "))
        end
        if plan.smelttime ~= nil then
            table.insert(lines, "Time: " .. tostring(math.ceil(plan.smelttime)) .. "s")
        end
    end
    return table.concat(lines, "\n")
end

return MAMForecast
