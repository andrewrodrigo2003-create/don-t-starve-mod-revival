local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local products = require("smelting_products")
local MAMConfig = require("mam/config")

local function L(ptbr, english)
    return MAMConfig.get("mam_language", "ptbr") == "en" and english or ptbr
end

local TAG_LABELS =
{
    copper = L("Cobre", "Copper"),
    iron = L("Ferro", "Iron"),
    gold = L("Ouro", "Gold"),
    metal = "Metal",
    moonglass = L("Vidro lunar", "Moonglass"),
    moon = L("Lunar", "Moon"),
    mineral = "Mineral",
    steel = L("Aço sombrio", "Shadow steel"),
    red = L("Vermelho", "Red"),
    blue = L("Azul", "Blue"),
    yellow = L("Amarelo", "Yellow"),
    gem = L("Gema", "Gem"),
}

local function display_name(prefab)
    local value = STRINGS.NAMES[string.upper(prefab)]
    return value or prefab
end

local function format_requirements(recipe)
    local parts = {}
    local cost = recipe.cost
    if cost == nil then
        return L("Carga mista (receita legada)", "Mixed load (legacy recipe)")
    end
    for tag, amount in pairs(cost.tags or {}) do
        table.insert(parts, (TAG_LABELS[tag] or tag) .. " × " .. tostring(amount))
    end
    for prefab, amount in pairs(cost.names or {}) do
        table.insert(parts, display_name(prefab) .. " × " .. tostring(amount))
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or L("Carga específica", "Recipe-specific load")
end

local function build_pages()
    local names = {}
    for name in pairs(products) do
        table.insert(names, name)
    end
    table.sort(names)

    local pages =
    {
        {
            title = L("Metalurgia", "Metalworking"),
            body = table.concat({
                L("GUIA DE CONSULTA", "READ-ONLY GUIDE"),
                "",
                L("A forja continua necessária para processar materiais. Este livro não desbloqueia receitas nem fabrica itens à distância.",
                    "The forge is still required to process materials. This book does not unlock recipes or craft items remotely."),
                "",
                L("Tags de ingredientes permitem que diferentes materiais registrados satisfaçam o mesmo requisito. Cargas mistas podem gerar resultados alternativos com probabilidades.",
                    "Ingredient tags allow different registered materials to satisfy the same requirement. Mixed loads may have weighted alternative outcomes."),
                "",
                L("A quantidade do lote depende dos materiais carregados e das configurações do servidor. Consulte a prévia da forja para a carga atual.",
                    "Batch quantity depends on the loaded materials and server settings. Use the live forge preview for the current load."),
            }, "\\n"),
        },
        {
            title = L("Materiais e progressão", "Materials & progression"),
            body = table.concat({
                L("Cobre: pó de cobre → minério de cobre → lingote de cobre.",
                    "Copper: copper dust → copper ore → copper ingot."),
                L("Ferro: pó de ferro → minério de ferro → lingote de ferro.",
                    "Iron: iron dust → iron ore → iron ingot."),
                L("Ouro: pó de ouro → pepita de ouro → lingote de ouro.",
                    "Gold: gold dust → gold nugget → gold ingot."),
                L("Bronze: 3 unidades de cobre + 1 unidade de ferro, conforme o custo da receita.",
                    "Bronze: 3 copper-value units + 1 iron-value unit, according to the recipe cost."),
                L("Vidro lunar: 2 unidades de vidro lunar + 1 unidade de material lunar.",
                    "Moonglass: 2 moonglass-value units + 1 moon-value unit."),
                L("Adamantium: 3 unidades de aço sombrio + 1 lingote de ferro nomeado.",
                    "Adamantium: 3 shadow-steel units + 1 named iron ingot."),
                "",
                L("A desmontagem recupera componentes canônicos registrados; não reproduz necessariamente os mesmos itens usados originalmente em cargas mistas.",
                    "Deconstruction recovers registered canonical components; it does not necessarily reproduce the exact items originally used in mixed loads."),
            }, "\\n"),
        },
        {
            title = L("Mineração e fontes", "Mining & sources"),
            body = table.concat({
                L("Rochas: rochas de ouro podem fornecer pó de ouro; rochas lunares e suas conchas podem fornecer materiais de ferro.",
                    "Boulders: gold boulders can yield gold dust; moon rocks and moon-rock shells can provide iron materials."),
                L("Cavernas: estalagmites e estalactites podem fornecer cobre, pó de ouro e, ocasionalmente, materiais de gema.",
                    "Caves: stalagmites and stalactites can provide copper, gold dust and occasional gem materials."),
                L("Ruínas: mecanismos de xadrez e sucata podem fornecer materiais de cobre, ferro e fragmentos de gemas.",
                    "Ruins: clockworks and chess junk can provide copper/iron materials and gem shards."),
                L("Mármore: árvores naturais e arbustos de mármore fornecem drops metalúrgicos; árvores plantadas não recebem o bônus de árvore natural.",
                    "Marble: natural marble trees and shrubs provide metallurgy drops; planted trees do not receive the natural-tree bonus."),
                L("Criaturas: cães de fogo e gelo podem fornecer fragmentos de gemas; tubarões fornecem escamas de tubarão.",
                    "Creatures: fire and ice hounds can provide gem shards; sharks provide sharkscale."),
                "",
                L("As chances são controladas pelas configurações do mod. Desativar uma fonte não remove os drops vanilla.",
                    "Drop chances are controlled by the mod settings. Disabling a source does not remove vanilla drops."),
            }, "\\n"),
        },
        {
            title = L("Bancada de Guerra", "War Bench"),
            body = table.concat({
                L("Equipamentos, ferramentas e estruturas metálicas selecionadas ficam disponíveis na Bancada de Guerra (ALCHEMY_ONE).",
                    "Metal equipment, tools and selected metal structures are available at the War Bench (ALCHEMY_ONE)."),
                "",
                L("Itens da progressão da Máquina de Ciência, do Motor de Alquimia e o transistor permanecem no caminho científico para evitar ciclos de pré-requisitos.",
                    "Science Machine and Alchemy Engine progression items, plus the transistor, remain on the science path to avoid prerequisite loops."),
                "",
                L("A migração de bancada altera apenas a tecnologia exigida e o filtro de criação. Ingredientes e metadados ativos de outros mods são preservados.",
                    "Station migration changes only the required technology and crafting filter. Live ingredients and metadata from other mods are preserved."),
            }, "\\n"),
        },
        {
            title = L("Desmontagem", "Deconstruction"),
            body = table.concat({
                L("Clique com o botão direito em um material metalúrgico recuperável perto da Bancada de Guerra.",
                    "Right-click a recoverable metallurgical material near the War Bench."),
                "",
                L("A recuperação padrão tem média de 75% por unidade de componente. A operação aceita somente materiais com regra explícita de retorno.",
                    "Standard recovery averages 75% per component unit. The action accepts only materials with an explicit return rule."),
                "",
                L("Wilson recupera 100% dos componentes listados. Winona recupera 100% dos metais não mágicos. Maxwell recupera 100% dos materiais sombrios; outros componentes seguem a taxa padrão.",
                    "Wilson recovers 100% of listed components. Winona recovers 100% of non-magical metals. Maxwell recovers 100% of shadow materials; other components use the standard rate."),
                "",
                L("Armas, armaduras, ferramentas, equipamentos e estruturas não podem ser desmontados. Materiais sem proveniência segura também não são aceitos.",
                    "Weapons, armor, tools, equipment and structures cannot be dismantled. Materials without safe provenance are also rejected."),
                "",
                L("A operação consome uma unidade mesmo quando o sorteio não retorna componentes. Não há nova tentativa gratuita nem conversão para um estágio superior.",
                    "The action consumes one unit even when the recovery roll returns no components. There are no free retries or upward conversions."),
            }, "\\n"),
        },
        {
            title = L("Automação por robô", "Collector robot automation"),
            body = table.concat({
                L("A opção de automação da forja por robô coletor vem desativada por padrão.",
                    "Collector robot forge automation is Off by default."),
                "",
                L("Com W.O.B.O.T. abastecido ou W.I.N.bot implantado e ativo por perto, a forja pode retirar apenas ingredientes registrados de baús e mochilas compatíveis próximos.",
                    "With a fueled W.O.B.O.T. or deployed, active W.I.N.bot nearby, the smelter can pull only registered ingredients from nearby compatible chests and packs."),
                "",
                L("Quando o lote termina, o produto vai para o armazenamento compatível mais próximo com espaço. Se não houver espaço, permanece pronto na forja para retirada manual.",
                    "When the batch finishes, the product goes to the nearest compatible storage with room. Otherwise it remains ready in the smelter for manual collection."),
                "",
                L("Inventários de jogadores e armazenamentos portáteis nunca são vasculhados nem esvaziados.",
                    "Player inventories and portable storage are never scanned or drained."),
            }, "\\n"),
        },
        {
            title = L("Compatibilidade e segurança", "Compatibility & safety"),
            body = table.concat({
                L("Overrides de receitas usam assinaturas vanilla protegidas. Se outro mod alterar uma receita protegida, Metals and More cede em vez de sobrescrever silenciosamente seus ingredientes.",
                    "Recipe overrides use guarded vanilla signatures. If another mod changes a protected recipe, Metals and More yields instead of silently replacing its ingredients."),
                "",
                L("Drops de cães do Uncompromising Mode usam Auto por padrão. Drops de escamas de tubarão são aditivos. Este mod não altera arquivos de outros mods.",
                    "Uncompromising Mode hound drops default to Auto. Sharkscale drops are additive. This mod does not edit other mods' files."),
                "",
                L("Sempre teste atualizações em um mundo separado antes de usar um save principal.",
                    "Always test updates in a separate world before using a main save."),
            }, "\\n"),
        },
    }

    local per_page = 3
    for first = 1, #names, per_page do
        local lines = {}
        local last = math.min(first + per_page - 1, #names)
        for index = first, last do
            local name = names[index]
            local recipe = products[name]
            table.insert(lines, display_name(name))
            table.insert(lines, L("  Tempo base: ", "  Base time: ") .. tostring(recipe.cooktime or 1) .. " s")
            table.insert(lines, L("  Saída: variável conforme o lote", "  Output: varies by batch"))
            if recipe.max_batch ~= nil then
                table.insert(lines, L("  Lote máximo de entrada: ", "  Max input batch: ") .. tostring(recipe.max_batch))
            end
            table.insert(lines, L("  Requisitos: ", "  Requirements: ") .. format_requirements(recipe))
            table.insert(lines, "")
        end
        table.insert(pages, {
            title = L("Receitas", "Recipes"),
            body = table.concat(lines, "\\n"),
        })
    end
    return pages
end

local MetallurgyBookScreen = Class(Screen, function(self, owner)
    Screen._ctor(self, "MetallurgyBookScreen")
    self.owner = owner
    self.pages = build_pages()
    self.page = 1

    local shade = self:AddChild(Image("images/global.xml", "square.tex"))
    shade:SetVAnchor(ANCHOR_MIDDLE)
    shade:SetHAnchor(ANCHOR_MIDDLE)
    shade:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade:SetTint(0, 0, 0, 0.78)

    self.root = self:AddChild(Widget("root"))
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)

    local panel = self.root:AddChild(Image("images/quagmire_recipebook.xml", "quagmire_recipe_menu_bg.tex"))
    panel:ScaleToSize(900, 560)

    self.title = self.root:AddChild(Text(HEADERFONT, 30, "", { 1, 0.84, 0.45, 1 }))
    self.title:SetPosition(0, 225)

    self.body = self.root:AddChild(Text(BODYTEXTFONT, 18, "", { 0.10, 0.10, 0.10, 1 }))
    self.body:SetPosition(0, 10)
    self.body:SetRegionSize(760, 390)
    self.body:SetHAlign(ANCHOR_LEFT)
    self.body:SetVAlign(ANCHOR_TOP)

    self.page_text = self.root:AddChild(Text(BODYTEXTFONT, 18, "", { 0.32, 0.22, 0.12, 1 }))
    self.page_text:SetPosition(0, -235)

    self.previous = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.previous:SetScale(0.35)
    self.previous:SetPosition(-300, -235)
    self.previous:SetText(L("Anterior", "Previous"))
    self.previous:SetTextSize(18)
    self.previous:SetOnClick(function() self:SetPage(self.page - 1) end)

    self.next = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.next:SetScale(0.35)
    self.next:SetPosition(300, -235)
    self.next:SetText(L("Próxima", "Next"))
    self.next:SetTextSize(18)
    self.next:SetOnClick(function() self:SetPage(self.page + 1) end)

    self.close = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.close:SetScale(0.28)
    self.close:SetPosition(405, 245)
    self.close:SetText("X")
    self.close:SetTextSize(22)
    self.close:SetOnClick(function() TheFrontEnd:PopScreen() end)

    self.default_focus = self.next
    self:SetPage(1)
end)

function MetallurgyBookScreen:SetPage(page)
    self.page = math.max(1, math.min(page, #self.pages))
    local data = self.pages[self.page]
    self.title:SetString(data.title)
    self.body:SetString(data.body)
    self.page_text:SetString(string.format(L("Página %d / %d", "Page %d / %d"), self.page, #self.pages))
end

function MetallurgyBookScreen:OnDestroy()
    if self.owner ~= nil and self.owner:IsValid() then
        self.owner._mam_metallurgy_book_open = nil
        POPUPS.MAM_METALLURGY_BOOK:Close(self.owner)
    end
    MetallurgyBookScreen._base.OnDestroy(self)
end

function MetallurgyBookScreen:OnControl(control, down)
    if MetallurgyBookScreen._base.OnControl(self, control, down) then
        return true
    end
    if not down and (control == CONTROL_CANCEL or control == CONTROL_MENU_BACK) then
        TheFrontEnd:PopScreen()
        return true
    end
    if not down and control == CONTROL_MENU_L2 then
        self:SetPage(self.page - 1)
        return true
    elseif not down and control == CONTROL_MENU_R2 then
        self:SetPage(self.page + 1)
        return true
    end
    return false
end

function MetallurgyBookScreen:GetHelpText()
    local controller_id = TheInput:GetControllerID()
    return TheInput:GetLocalizedControl(controller_id, CONTROL_CANCEL) .. " " .. STRINGS.UI.HELP.BACK
end

return MetallurgyBookScreen
