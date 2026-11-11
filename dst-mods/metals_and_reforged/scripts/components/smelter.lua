local smelting = require "smelting"
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")

-- Tag propria, em vez de "harvestable": o componente vanilla harvestable tambem
-- escreve essa tag no entity, e reusa-la aqui faria o farm system enxergar a
-- fundicao. O verb continua HARVEST (identidade original), so o marcador e nosso.
local READY_TAG = "mam_readytoharvest"

local stack_size = function(item)
    if item ~= nil and item.components.stackable ~= nil and item.components.stackable:IsStack() then
        return item.components.stackable:StackSize()
    end
    return 1
end

local Smelter = Class(function(self, inst)
    self.inst = inst

    self.issmelting = nil
    self.product = nil
    self.batch = 1
    self.canharvest = nil

    self.smelttime = 0

    self.startsmeltingfn = nil
    self.donesmeltingfn = nil
    self.onharvest = nil
    self.onplanfn = nil
    -- Recibo das entradas debitadas do lote ativo; so e confirmado ao concluir.
    self.active_receipt = nil

    -- O componente permanece ocioso sem polling; o timer so nasce ao iniciar/resumir um lote.
end)

---------------------------------------------------------------------------
-- Leitura e consumo da carga
---------------------------------------------------------------------------

--- Carga atual, na ordem dos slots, com a contagem real de cada pilha.
function Smelter:GetItems()
    local items = {}
    local container = self.inst.components.container
    if container == nil then
        return items
    end

    for slot = 1, container.numslots do
        local item = container.slots[slot]
        if item ~= nil and item:IsValid() then
            table.insert(items, { slot = slot, prefab = item.prefab, count = stack_size(item) })
        end
    end
    return items
end

--- Consome `amount` pecas de um slot, espelhando a regra de tryconsume() do
--- container vanilla: pilha parcial reduz o tamanho, pilha inteira sai do slot.
function Smelter:CanConsumePlan(consumed)
    local container = self.inst.components.container
    if container == nil or type(consumed) ~= "table" or #consumed == 0 then
        return false
    end

    -- Aggregate by slot so duplicate requirements cannot overdraw one stack.
    local required = {}
    for _, entry in ipairs(consumed) do
        if type(entry) ~= "table"
            or type(entry.slot) ~= "number"
            or entry.slot < 1
            or entry.slot % 1 ~= 0
            or type(entry.prefab) ~= "string"
            or type(entry.count) ~= "number"
            or entry.count < 1
            or entry.count % 1 ~= 0 then
            return false
        end

        local current = required[entry.slot]
        if current ~= nil and current.prefab ~= entry.prefab then
            return false
        end
        if current == nil then
            current = { prefab = entry.prefab, count = 0 }
            required[entry.slot] = current
        end
        current.count = current.count + entry.count
    end

    for slot, entry in pairs(required) do
        local item = container.slots[slot]
        if item == nil or not item:IsValid()
            or item.prefab ~= entry.prefab
            or stack_size(item) < entry.count then
            return false
        end
    end
    return next(required) ~= nil
end

function Smelter:ConsumeSlot(slot, amount, expected_prefab)
    local container = self.inst.components.container
    if container == nil or type(amount) ~= "number"
        or amount < 1 or amount % 1 ~= 0 then
        return 0
    end

    local item = container.slots[slot]
    if item == nil or not item:IsValid()
        or (expected_prefab ~= nil and item.prefab ~= expected_prefab) then
        return 0
    end

    local available = stack_size(item)
    if available < amount then
        return 0
    end

    local stackable = item.components.stackable
    if stackable == nil or not stackable:IsStack() then
        if amount ~= 1 then
            return 0
        end
        container:RemoveItem(item):Remove()
        return 1
    elseif stackable.stacksize > amount then
        stackable:SetStackSize(stackable.stacksize - amount)
        return amount
    else
        local taken = stackable.stacksize
        container:RemoveItem(item, true):Remove()
        return taken
    end
end

--- Publicacao unica para a UI: configuracao de SIM deste servidor + ultimo
--- plano sorteado, na mesma string. Assim o cliente nunca ve um sem o outro,
--- nem perde os valores de lote quando a maquina volta para idle.
--- Formato: "c|batch|cap|crescimento p|produto|quantidade|fase"
function Smelter:PublishPlan()
    if self.inst.mam_plan == nil then
        return
    end

    local phase = "idle"
    if self.canharvest then
        phase = "harvest"
    elseif self.issmelting then
        phase = "smelting"
    end

    local product = self.product or ""
    if product ~= "" and smelting.GetSmelterRecipe(self.inst.prefab, product) == nil then
        -- produto desconhecido (outro mod?): nao publicamos plano
        product = ""
    end

    local batch = MAMConfig.on("mam_batch") and 1 or 0
    local cap = MAMConfig.int("mam_batch_cap", 10)
    local growth = MAMConfig.int("mam_batch_time", 25)

    self.inst.mam_plan:set(("c|%d|%d|%d p|%s|%d|%s"):format(batch, cap, growth, product, self.batch or 1, phase))
end

--- Alias historico: a configuracao sempre viaja junto com o plano.
function Smelter:PublishConfig()
    self:PublishPlan()
end

---------------------------------------------------------------------------
-- Ciclo de fundicao
---------------------------------------------------------------------------

function Smelter:StartSmelting(doer)
    local container = self.inst.components.container
    if container == nil then
        return false
    end

    local items = self:GetItems()
    if #items == 0 then
        return false
    end

    local ok, plan = MAMLog.Try("smelting.CalculateSmelterPlan",
        smelting.CalculateSmelterPlan, self.inst.prefab, items)
    if not ok or plan == nil or plan.state ~= "ready" or plan.product == nil then
        return false
    end

    -- Validate the complete plan before changing machine state or consuming input.
    if not self:CanConsumePlan(plan.consumed) then
        MAMLog.Warn("plano de fundicao desatualizado ou inconsistente")
        return false
    end

    self.issmelting = true
    self.canharvest = nil
    self.product = plan.product
    self.batch = plan.count or 1
    self.smelttime = plan.smelttime or 1
    self.active_receipt = {}
    self.refund_pending = nil

    -- Registra cada debito confirmado para permitir rollback se o lote ativo
    -- for cancelado antes de concluir.
    for i = #plan.consumed, 1, -1 do
        local entry = plan.consumed[i]
        local consumed = self:ConsumeSlot(entry.slot, entry.count, entry.prefab)
        if consumed > 0 then
            table.insert(self.active_receipt, { prefab = entry.prefab, count = consumed })
        end
        if consumed ~= entry.count then
            MAMLog.Warn("consumo divergente no slot %s: esperado %d, consumido %d",
                tostring(entry.slot), entry.count, consumed)
            self:ResetSmelter()
            return false
        end
    end

    if self.startsmeltingfn then
        MAMLog.Try("smelter:startsmeltingfn", self.startsmeltingfn, self.inst)
    end

    container:Close()
    container.canbeopened = false

    self:PublishPlan()
    self:Update(0)

    if self.onplanfn then
        MAMLog.Try("smelter:onplanfn", self.onplanfn, self.inst, plan)
    end

    return true
end

function Smelter:ResumeSmelting()
    self.issmelting = true

    if self.startsmeltingfn then
        MAMLog.Try("smelter:startsmeltingfn", self.startsmeltingfn, self.inst)
    end

    local container = self.inst.components.container
    if container ~= nil then
        container:Close()
        container.canbeopened = false
    end

    self:PublishPlan()
    -- Em um save feito exatamente no fim da contagem, a conclusao sera
    -- agendada por OnLoad depois que os outros componentes restaurarem dados.
    if self.smelttime > 0 then
        self:Update(0)
    end
end

function Smelter:DoneSmelting()
    if self.refund_pending then
        return false
    end

    self:StopUpdating()
    -- O custo foi confirmado: nao ha reembolso apos concluir a fundicao.
    self.active_receipt = nil
    self.issmelting = nil
    self.canharvest = true

    if self.donesmeltingfn then
        MAMLog.Try("smelter:donesmeltingfn", self.donesmeltingfn, self.inst)
    end

    self.inst:AddTag(READY_TAG)

    local container = self.inst.components.container
    if container ~= nil then
        container.canbeopened = false

        -- Opcao "sobras": 0 = comportamento original, destroi o que restou.
        if not MAMConfig.on("mam_leftovers") then
            container:DestroyContents()
        end
    end

    self:PublishPlan()
end

function Smelter:RefundActiveReceipt()
    local receipt = self.active_receipt
    if type(receipt) ~= "table" or #receipt == 0 then
        self.active_receipt = nil
        return true
    end

    local lootdropper = self.inst.components.lootdropper
    if lootdropper == nil or type(lootdropper.FlingItem) ~= "function" then
        MAMLog.Warn("nao foi possivel devolver recibo: lootdropper indisponivel")
        return false
    end

    -- Prepara todos os itens antes de entregar qualquer um. Se um prefab nao
    -- puder nascer, remove os temporarios e mantem o recibo sem alteracao.
    local staged = {}
    for index, entry in ipairs(receipt) do
        if type(entry) ~= "table" or type(entry.prefab) ~= "string"
            or type(entry.count) ~= "number" or entry.count < 1
            or entry.count % 1 ~= 0 then
            for _, pending in ipairs(staged) do
                if pending.item ~= nil and pending.item:IsValid() then
                    pending.item:Remove()
                end
            end
            MAMLog.Warn("recibo de estorno invalido; lote permanece protegido")
            return false
        end

        local remaining = entry.count
        while remaining > 0 do
            local ok, item = MAMLog.Try("smelter:refund:SpawnPrefab", SpawnPrefab, entry.prefab)
            if not ok or item == nil then
                for _, pending in ipairs(staged) do
                    if pending.item ~= nil and pending.item:IsValid() then
                        pending.item:Remove()
                    end
                end
                MAMLog.Warn("estorno de %s pausado; %d unidade(s) continuam no recibo",
                    entry.prefab, entry.count)
                return false
            end

            local stackable = item.components ~= nil and item.components.stackable or nil
            local amount = 1
            if stackable ~= nil then
                local maxsize = tonumber(stackable.maxsize) or 20
                if maxsize > 0 then
                    amount = math.min(remaining, maxsize)
                end
                if amount > 1 then
                    stackable:SetStackSize(amount)
                end
            end

            table.insert(staged, { item = item, receipt_index = index, amount = amount })
            remaining = remaining - amount
        end
    end

    -- FlingItem e sincrono no lootdropper vanilla. Atualiza o recibo a cada
    -- entrega para que uma falha posterior nao duplique itens ja lancados.
    for i, pending in ipairs(staged) do
        local ok, delivered = MAMLog.Try("smelter:refund:FlingItem",
            lootdropper.FlingItem, lootdropper, pending.item)
        if not ok or delivered == false then
            for j = i, #staged do
                local item = staged[j].item
                if item ~= nil and item:IsValid() then
                    item:Remove()
                end
            end
            local remaining_receipt = {}
            for _, entry in ipairs(receipt) do
                if entry.count > 0 then
                    table.insert(remaining_receipt, entry)
                end
            end
            self.active_receipt = #remaining_receipt > 0 and remaining_receipt or nil
            MAMLog.Warn("estorno parcialmente entregue; recibo restante preservado")
            return false
        end

        local entry = receipt[pending.receipt_index]
        entry.count = entry.count - pending.amount
    end

    local remaining_receipt = {}
    for _, entry in ipairs(receipt) do
        if entry.count > 0 then
            table.insert(remaining_receipt, entry)
        end
    end
    self.active_receipt = #remaining_receipt > 0 and remaining_receipt or nil
    return self.active_receipt == nil
end

function Smelter:ResetSmelter()
    local had_receipt = self.active_receipt ~= nil
    local was_active = self.issmelting == true or had_receipt
    if had_receipt and not self:RefundActiveReceipt() then
        -- Keep the transaction in a dedicated retry state. Never let the
        -- normal smelting timer complete a batch whose rollback is pending.
        self.refund_pending = true
        self.issmelting = true
        self.canharvest = nil
        local container = self.inst.components.container
        if container ~= nil then
            container:Close()
            container.canbeopened = false
        end
        self:StartUpdating()
        return false
    elseif was_active and not had_receipt then
        MAMLog.WarnOnce("smelter:legacy-active-without-receipt",
            "fundicao ativa sem recibo salvo; materiais debitados em save antigo nao podem ser reconstruidos")
    end

    self.issmelting = nil
    self.refund_pending = nil
    self.product = nil
    self.canharvest = nil
    self.batch = 1
    self.smelttime = 0

    local container = self.inst.components.container
    if container ~= nil then
        container.canbeopened = true

        -- Cancelamento ativo e rollback integral: devolve tambem as entradas
        -- ja debitadas, independentemente da antiga opcao de sobras.
        if was_active or MAMConfig.on("mam_leftovers") then
            container:DropEverything()
        else
            container:DestroyContents()
        end
    end

    self.inst:RemoveTag(READY_TAG)

    self:StopUpdating()

    self:PublishPlan()
    return true
end

function Smelter:Harvest(harvester)
    if not self.canharvest then
        return false
    end

    -- Keep the ready output entitlement if this callback has no valid recipient.
    if self.product ~= nil and (harvester == nil or harvester.components == nil
        or harvester.components.inventory == nil) then
        return false
    end

    if self.product ~= nil and harvester ~= nil and harvester.components.inventory ~= nil then
        local remaining = self.batch or 1
        if remaining < 1 then
            remaining = 1
        end

        while remaining > 0 do
            local loot = SpawnPrefab(self.product)
            if loot == nil then
                -- Preserve the undelivered remainder. Earlier stacks may
                -- already have been delivered; retrying must not duplicate them.
                self.batch = remaining
                MAMLog.Warn("produto %s nao pode ser gerado; %d unidade(s) pendentes",
                    tostring(self.product), remaining)
                self:PublishPlan()
                return false
            end

            local n = remaining
            if loot.components.stackable ~= nil then
                local maxsize = loot.components.stackable.maxsize or 20
                if maxsize > 0 and n > maxsize then
                    n = maxsize
                end
                if n > 1 then
                    loot.components.stackable:SetStackSize(n)
                end
            else
                n = 1
            end

            loot.targetMoisture = 0
            loot:DoTaskInTime(2 * FRAMES, function()
                if loot.components.moisturelistener then
                    loot.components.moisturelistener.moisture = loot.targetMoisture
                    loot.targetMoisture = nil
                    loot.components.moisturelistener:DoUpdate()
                end
            end)

            harvester.components.inventory:GiveItem(loot, nil, self.inst:GetPosition())

            remaining = remaining - n
        end
    end

    if self.onharvest then
        MAMLog.Try("smelter:onharvest", self.onharvest, self.inst)
    end

    self:ResetSmelter()

    return true
end

--- Quantidade que a carga atual produziria, sem side effect. Para a UI.
function Smelter:Forecast()
    local ok, plan = MAMLog.Try("smelting.ForecastSmelterPlan",
        smelting.ForecastSmelterPlan, self.inst.prefab, self:GetItems())
    if not ok then
        return nil
    end
    return plan
end

------------------------------------------------------------------------------------------------------
-- Update Functions

--- Publica cfg+plano assim que o mundo carrega: a UI do cliente consegue
--- prever a quantidade certa antes da primeira fundicao da sessao.
function Smelter:OnEnterWorld()
    self:PublishPlan()
end

--- Recarga de configuracao depois de construir a maquina no mundo ja iniciado.
function Smelter:OnBuilt()
    self:PublishPlan()
end

local function OnDoUpdate(inst, self, period)
    self:Update(period)
end

function Smelter:StartUpdating()
    if self.task == nil and self.issmelting and not self.canharvest then
        self.task = self.inst:DoPeriodicTask(0.5, OnDoUpdate, nil, self, 0.5)
    end
end

function Smelter:StopUpdating()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function Smelter:Update(dt)
    -- A failed refund is not a smelting job. Retry the rollback first and
    -- never decrement the cook timer or grant output while inputs are owed.
    if self.refund_pending then
        if not self:ResetSmelter() then
            self:StartUpdating()
        end
        return
    end

    if not self.issmelting or self.canharvest then
        self:StopUpdating()
        return
    end

    self.smelttime = (tonumber(self.smelttime) or 0) - (tonumber(dt) or 0)
    if self.smelttime <= 0 then
        if self.product ~= nil then
            self:DoneSmelting()
        elseif not self:ResetSmelter() then
            -- A devolucao pode falhar temporariamente; mantenha um unico timer para retry.
            self:StartUpdating()
        end
        return
    end

    self:StartUpdating()
end

------------------------------------------------------------------------------------------------------
-- Saving and Loading Functions

function Smelter:OnSave()
    return
    {
        canharvest = self.canharvest,
        product = self.product,
        batch = self.batch,
        smelttime = self.smelttime,
        issmelting = self.issmelting,
        active_receipt = self.active_receipt,
        refund_pending = self.refund_pending,
    }
end

function Smelter:OnLoad(data)
    local defer_expired_completion = false

    if data ~= nil then
        self.product = data.product or nil
        self.batch = data.batch or 1
        self.active_receipt = nil
        self.refund_pending = data.refund_pending == true
        if type(data.active_receipt) == "table" then
            local receipt = {}
            for _, entry in ipairs(data.active_receipt) do
                if type(entry) == "table" and type(entry.prefab) == "string"
                    and type(entry.count) == "number" and entry.count > 0
                    and entry.count % 1 == 0 then
                    table.insert(receipt, { prefab = entry.prefab, count = entry.count })
                end
            end
            self.active_receipt = #receipt > 0 and receipt or nil
        end

        -- A devolucao pendente tem prioridade sobre qualquer estado de lote:
        -- um rollback nunca pode virar produto apos carregar o mundo.
        if self.refund_pending then
            defer_expired_completion = true
            self.issmelting = true
            self.canharvest = nil
            local container = self.inst.components.container
            if container ~= nil then
                container:Close()
                container.canbeopened = false
            end
            self:PublishPlan()
            self:Update(0)
        -- Estado pronto-colher tem precedencia sobre issmelting em saves
        -- antigos/inconsistentes. Nao chamar DoneSmelting durante OnLoad:
        -- o container pode ainda nao ter restaurado as sobras.
        elseif data.canharvest then
            -- Save pronto para colher ja confirmou o custo do lote.
            self.active_receipt = nil
            self.canharvest = true
            self.issmelting = nil
            self.inst:AddTag(READY_TAG)

            local container = self.inst.components.container
            if container ~= nil then
                container.canbeopened = false
            end

            if self.donesmeltingfn then
                self.inst:DoTaskInTime(2, function()
                    MAMLog.Try("smelter:donesmeltingfn", self.donesmeltingfn, self.inst)
                end)
            end
        elseif data.issmelting then
            if self.active_receipt == nil then
                MAMLog.WarnOnce("smelter:legacy-save-without-receipt",
                    "save antigo de fundicao ativa nao possui recibo; materiais ja debitados nao podem ser reconstruidos")
            end
            -- Saves antigos ou interrompidos podem nao ter smelttime; tratar
            -- nil/valor invalido como contagem concluida, nunca subtrair nil.
            local remaining = tonumber(data.smelttime) or 0
            self.smelttime = math.max(0, remaining)

            if self.product ~= nil then
                self.issmelting = true
                self:ResumeSmelting()

                if self.smelttime <= 0 then
                    defer_expired_completion = true
                    self.inst:DoTaskInTime(0, function()
                        if self.issmelting and not self.canharvest then
                            if self.product ~= nil then
                                self:DoneSmelting()
                            else
                                self:ResetSmelter()
                            end
                        end
                    end)
                end
            else
                -- Sem produto salvo nao ha resultado seguro para gerar.
                self:ResetSmelter()
            end
        end
    end

    self:PublishPlan()
    -- Evita que Update(0) conclua antes da tarefa deferida e da restauracao
    -- do container em saves cujo tempo restante era zero/ausente.
    if not defer_expired_completion then
        self:Update(0)
    end
end

return Smelter
