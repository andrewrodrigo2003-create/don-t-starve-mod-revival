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

    self:Update(0)
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
function Smelter:ConsumeSlot(slot, amount)
    local container = self.inst.components.container
    if container == nil or amount <= 0 then
        return 0
    end

    local item = container.slots[slot]
    if item == nil or not item:IsValid() then
        return 0
    end

    local stackable = item.components.stackable
    if stackable == nil then
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

    self.issmelting = true
    self.canharvest = nil
    self.product = plan.product
    self.batch = plan.count or 1
    self.smelttime = plan.smelttime or 1

    if self.startsmeltingfn then
        self.startsmeltingfn(self.inst)
    end

    -- Consumo exato do lote. O que sobrar fica nos slots e volta para o
    -- jogador no harvest, em vez de ser destruido silenciosamente.
    if type(plan.consumed) == "table" then
        for i = #plan.consumed, 1, -1 do
            local c = plan.consumed[i]
            self:ConsumeSlot(c.slot, c.count)
        end
    end

    container:Close()
    container.canbeopened = false

    self:PublishPlan()
    self:Update(0)

    if self.onplanfn then
        self.onplanfn(self.inst, plan)
    end

    return true
end

function Smelter:ResumeSmelting()
    self.issmelting = true

    if self.startsmeltingfn then
        self.startsmeltingfn(self.inst)
    end

    local container = self.inst.components.container
    if container ~= nil then
        container:Close()
        container.canbeopened = false
    end

    self:PublishPlan()
    self:Update(0)
end

function Smelter:DoneSmelting()
    self.issmelting = nil
    self.canharvest = true

    if self.donesmeltingfn then
        self.donesmeltingfn(self.inst)
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

function Smelter:ResetSmelter()
    self.issmelting = nil
    self.product = nil
    self.canharvest = nil
    self.batch = 1

    self.smelttime = 0

    local container = self.inst.components.container
    if container ~= nil then
        container.canbeopened = true

        -- Sem sobras nao ha nada a devolver; com sobras, elas voltam ao jogador.
        if MAMConfig.on("mam_leftovers") then
            container:DropEverything()
        end
    end

    self.inst:RemoveTag(READY_TAG)

    if self.task then
        self.task:Cancel()
        self.task = nil
    end

    self:PublishPlan()
end

function Smelter:Harvest(harvester)
    if not self.canharvest then
        return false
    end

    if self.onharvest then
        self.onharvest(self.inst)
    end

    if self.product ~= nil and harvester ~= nil and harvester.components.inventory ~= nil then
        local remaining = self.batch or 1
        if remaining < 1 then
            remaining = 1
        end

        while remaining > 0 do
            local loot = SpawnPrefab(self.product)
            if loot == nil then
                MAMLog.Warn("produto %s nao pode ser gerado", tostring(self.product))
                break
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

function Smelter:Update(dt)
    if self.issmelting and not self.canharvest then
        self.smelttime = self.smelttime - dt

        if self.smelttime <= 0 then
            if self.product ~= nil then
                self:DoneSmelting()
            else
                -- Nenhum produto valido: devolve a carga em vez de travar a maquina.
                self:ResetSmelter()
            end
        end
    end

    if self.task == nil then
        self.task = self.inst:DoPeriodicTask(0.5, OnDoUpdate, nil, self, 0.5)
    end
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
    }
end

function Smelter:OnLoad(data)
    if data ~= nil then
        self.product = data.product or nil
        self.batch = data.batch or 1

        if data.issmelting and data.smelttime ~= 0 then
            self.smelttime = data.smelttime
            self.issmelting = true
            self:ResumeSmelting()
        end

        -- Restaurar o estado pronto-colher: NAO podemos chamar DoneSmelting
        -- aqui, porque ele destrui a carga e o container ainda nao restaurou
        -- as sobras -> perda de item do jogador ao carregar o mundo.
        if data.canharvest then
            self.canharvest = true
            self.issmelting = nil
            self.inst:AddTag(READY_TAG)

            local container = self.inst.components.container
            if container ~= nil then
                container.canbeopened = false
            end

            if self.donesmeltingfn then
                self.inst:DoTaskInTime(2, function()
                    self.donesmeltingfn(self.inst)
                end)
            end
        end
    end

    self:PublishPlan()
    self:Update(0)
end

return Smelter
