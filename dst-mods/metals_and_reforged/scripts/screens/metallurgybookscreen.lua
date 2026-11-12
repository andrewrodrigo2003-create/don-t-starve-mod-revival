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

    self.body = self.root:AddChild(Text(BODYTEXTFONT, 21, "", UICOLOURS.BLACK))
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
    self.previous:SetClickable(self.page > 1)
    self.next:SetClickable(self.page < #self.pages)
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
