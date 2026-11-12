local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local products = require("smelting_products")

local TAG_LABELS =
{
    copper = "Copper / Cobre",
    iron = "Iron / Ferro",
    gold = "Gold / Ouro",
    metal = "Metal",
    moonglass = "Moonglass / Vidro lunar",
    moon = "Moon / Lunar",
    mineral = "Mineral",
    steel = "Steel / Aço sombrio",
    red = "Red / Vermelho",
    blue = "Blue / Azul",
    yellow = "Yellow / Amarelo",
    gem = "Gem / Gema",
}

local function display_name(prefab)
    local value = STRINGS.NAMES[string.upper(prefab)]
    return value or prefab
end

local function format_requirements(recipe)
    local parts = {}
    local cost = recipe.cost
    if cost == nil then
        return "Mixed load / Carga mista (legacy recipe)"
    end
    for tag, amount in pairs(cost.tags or {}) do
        table.insert(parts, (TAG_LABELS[tag] or tag) .. " × " .. tostring(amount))
    end
    for prefab, amount in pairs(cost.names or {}) do
        table.insert(parts, display_name(prefab) .. " × " .. tostring(amount))
    end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "Recipe-specific load / Carga específica"
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
            title = "Metalworking / Metalurgia",
            body = table.concat({
                "READ-ONLY GUIDE / GUIA DE CONSULTA",
                "",
                "The forge is still required to process materials. This book does not unlock recipes or craft items remotely.",
                "A forja continua necessária para processar materiais. Este livro não desbloqueia receitas nem fabrica itens à distância.",
                "",
                "Ingredient tags allow different registered materials to satisfy the same requirement. Mixed loads may have weighted alternative outcomes.",
                "Tags permitem que materiais registrados diferentes satisfaçam o mesmo requisito. Cargas mistas podem ter resultados alternativos com probabilidades.",
                "",
                "Batch quantity depends on the materials loaded and the server's batch settings. Use the live forge preview for the current load.",
                "A quantidade do lote depende dos materiais e das configurações do servidor. Consulte a prévia da forja para a carga atual.",
            }, "\n"),
        },
    }

    table.insert(pages, {
        title = "Materials & progression / Materiais e progressão",
        body = table.concat({
            "Basic conversion chain / Cadeia básica:",
            "Metal ore → dust → smelted ingot. Alloys consume their exact component recipe; the forge planner is the authority for batch costs.",
            "Minério → poeira → lingote fundido. Ligas consomem os componentes exatos; a prévia da forja mostra o custo do lote.",
            "",
            "Copper / Cobre: copper dust → copper ore → copper ingot.",
            "Iron / Ferro: iron dust → iron ore → iron ingot.",
            "Gold / Ouro: gold dust → gold nugget → gold ingot.",
            "Bronze: 3 copper ore + 1 iron ore.",
            "Moonglass: 2 moonglass + 1 moonrocknugget.",
            "Adamantium: 3 nightmare fuel + 1 iron ingot.",
            "",
            "The guide reflects the active smelting data; mixed loads and batch settings can change the number produced.",
            "O guia reflete os dados de fundição ativos; cargas mistas e configurações de lote alteram a quantidade produzida.",
        }, "\\n"),
    })

    table.insert(pages, {
        title = "Mining & sources / Mineração e fontes",
        body = table.concat({
            "Boulders / Rochas: gold boulders can yield gold dust; moon rocks and moon-rock shells provide iron materials.",
            "Cave formations / Formações de caverna: stalagmites and stalactites provide copper materials, gold dust and occasional gem materials.",
            "Ruins / Ruínas: clockworks and chess junk can yield copper/iron materials and gem shards.",
            "Marble / Mármore: natural marble trees and marble shrubs provide metal-related drops; planted marble trees are excluded from the natural-tree bonus.",
            "Creatures / Criaturas: fire and ice hound gem shards use Auto mode to yield to Uncompromising Mode; sharks provide sharkscale.",
            "",
            "Drop chances remain controlled by the mod configuration. Disabling a source does not remove its vanilla drops.",
            "As chances continuam controladas pelas opções do mod. Desativar uma fonte não remove os drops vanilla.",
        }, "\\n"),
    })

    table.insert(pages, {
        title = "War Bench / Bancada de Guerra",
        body = table.concat({
            "Metal equipment, tools and selected metal structures are available at the War Bench (ALCHEMY_ONE).",
            "Equipamentos, ferramentas e estruturas metálicas selecionadas ficam na Bancada de Guerra (ALCHEMY_ONE).",
            "",
            "The Science Machine / Alchemy Engine progression items and transistor remain on the science path so the War Bench does not become a prerequisite loop.",
            "Itens de progressão da Máquina de Ciência / Motor de Alquimia e o transistor permanecem na progressão científica para evitar um ciclo de pré-requisitos.",
            "",
            "Recipe station migration changes only the required technology and crafting filter. It preserves live ingredient lists and recipe metadata from other mods.",
            "A migração altera apenas a tecnologia e o filtro da bancada. Ingredientes e metadados de receitas de outros mods são preservados.",
        }, "\\n"),
    })

    table.insert(pages, {
        title = "Deconstruction / Desmontagem",
        body = table.concat({
            "Right-click a supported metal material or crafted metal item while near the War Bench.",
            "Clique com o botão direito em um material metálico ou equipamento compatível perto da Bancada de Guerra.",
            "",
            "Standard recovery: 75% average per ingredient unit. Item durability scales equipment salvage; a fully depleted item has no remaining salvage.",
            "Retorno padrão: média de 75% por unidade de ingrediente. A durabilidade reduz o retorno de equipamentos; um item totalmente gasto não tem sucata restante.",
            "",
            "Wilson: 100% of listed components. Winona: 100% for non-magical metals. Maxwell: 100% for shadow materials; other components keep the standard rate.",
            "Wilson: 100% dos componentes listados. Winona: 100% dos metais não mágicos. Maxwell: 100% dos materiais sombrios; os demais seguem a taxa padrão.",
            "",
            "WX-78 and Wickerbottom have no special recovery bonus assigned yet. The live recipe is used for crafted equipment, so other mods' ingredient changes are respected.",
            "WX-78 e Wickerbottom ainda não têm bônus especial. Equipamentos usam a receita ativa, respeitando mudanças de ingredientes feitas por outros mods.",
            "",
            "The operation consumes one item even if the random recovery roll returns nothing. No retry exploit, upward conversion or free material loop is intended.",
            "A operação consome um item mesmo se o sorteio não devolver materiais. Não há tentativa gratuita, conversão para cima ou ciclo de materiais infinitos.",
        }, "\\n"),
    })

    table.insert(pages, {
        title = "Collector robot automation / Automação",
        body = table.concat({
            "Optional setting: Collector robot forge automation (default Off).",
            "Opção: Automação da forja por robô coletor (desativada por padrão).",
            "",
            "With a fueled, active W.O.B.O.T. or deployed W.I.N.bot nearby, the smelter can pull only registered smelting ingredients from nearby compatible chests and packs.",
            "Com W.O.B.O.T. abastecido ou W.I.N.bot implantado e ativo por perto, a forja puxa apenas ingredientes registrados de baús e mochilas compatíveis próximos.",
            "",
            "When the batch is ready, the output is deposited into the nearest compatible storage with enough room. If none has space, the output remains ready in the smelter for manual collection.",
            "Quando o lote termina, o produto vai para o armazenamento compatível mais próximo com espaço. Se nenhum tiver espaço, o produto fica pronto na forja para retirada manual.",
            "",
            "Player inventories and portable storage are never scanned or drained.",
            "Inventários de jogadores e armazenamentos portáteis nunca são vasculhados ou esvaziados.",
        }, "\\n"),
    })

    table.insert(pages, {
        title = "Compatibility & safety / Compatibilidade e segurança",
        body = table.concat({
            "Recipe overrides use a guarded vanilla signature. When another mod changes a protected recipe, Metals and More yields instead of silently replacing its ingredients.",
            "Overrides usam assinaturas vanilla protegidas. Quando outro mod altera uma receita protegida, Metals and More cede em vez de sobrescrever os ingredientes.",
            "",
            "Uncompromising Mode hound drops default to Auto. Shark materials are additive. The guide and forge do not modify Uncompromising Mode files.",
            "Drops de hounds do Uncompromising Mode usam Auto por padrão. Materiais de tubarão são aditivos. O guia e a forja não alteram arquivos do Uncompromising Mode.",
            "",
            "Always test new changes in a separate world before using a main save.",
            "Sempre teste atualizações em um mundo separado antes de usar um save principal.",
        }, "\\n"),
    })

    local per_page = 4
    for first = 1, #names, per_page do
        local lines = {}
        local last = math.min(first + per_page - 1, #names)
        for index = first, last do
            local name = names[index]
            local recipe = products[name]
            table.insert(lines, display_name(name))
            table.insert(lines, "  Base time / Tempo base: " .. tostring(recipe.cooktime or 1) .. " s")
            table.insert(lines, "  Output / Saída: variable by batch / variável por lote")
            table.insert(lines, "  Requirements / Requisitos: " .. format_requirements(recipe))
            table.insert(lines, "")
        end
        table.insert(pages, {
            title = "Recipes / Receitas",
            body = table.concat(lines, "\n"),
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

    self.title = self.root:AddChild(Text(HEADERFONT, 30, "", UICOLOURS.GOLD))
    self.title:SetPosition(0, 225)

    self.body = self.root:AddChild(Text(BODYTEXTFONT, 18, "", UICOLOURS.BLACK))
    self.body:SetPosition(0, 10)
    self.body:SetRegionSize(760, 390)
    self.body:SetHAlign(ANCHOR_LEFT)
    self.body:SetVAlign(ANCHOR_TOP)

    self.page_text = self.root:AddChild(Text(BODYTEXTFONT, 18, "", UICOLOURS.BROWN_DARK))
    self.page_text:SetPosition(0, -235)

    self.previous = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.previous:SetScale(0.35)
    self.previous:SetPosition(-300, -235)
    self.previous:SetText("Previous / Anterior")
    self.previous:SetTextSize(18)
    self.previous:SetOnClick(function() self:SetPage(self.page - 1) end)

    self.next = self.root:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.next:SetScale(0.35)
    self.next:SetPosition(300, -235)
    self.next:SetText("Next / Próxima")
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
    self.page = math.clamp(page, 1, #self.pages)
    local data = self.pages[self.page]
    self.title:SetString(data.title)
    self.body:SetString(data.body)
    self.page_text:SetString(string.format("Page %d / %d", self.page, #self.pages))
end

function MetallurgyBookScreen:OnDestroy()
    if self.owner ~= nil then
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
