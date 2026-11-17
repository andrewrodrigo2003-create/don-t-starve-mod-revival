-- Centralized MAM localization. Default language: Brazilian Portuguese.
-- Keep keys owned by this mod; never replace another mod's localization table.
local STRINGS = GLOBAL.STRINGS
local MAMConfig = GLOBAL.require("mam/config")
local language = MAMConfig.get("mam_language", "ptbr")
local use_english = language == "en"

local function L(ptbr, english)
    return use_english and english or ptbr
end

local ITEMS =
{
    COPPER_DUST = { "Pó de cobre", "Copper Dust", "Um pó metálico avermelhado.", "A reddish metallic dust." },
    COPPER_ORE = { "Minério de cobre", "Copper Ore", "Um metal relativamente macio.", "A relatively soft metal." },
    COPPER_INGOT = { "Lingote de cobre", "Copper Ingot", "Pode ser usado para fabricar peças de cobre.", "Useful for crafting copper components." },
    IRON_DUST = { "Pó de ferro", "Iron Dust", "Parece limalha de ferro.", "Looks like iron filings." },
    IRON_ORE = { "Minério de ferro", "Iron Ore", "Um minério resistente e versátil.", "A sturdy and versatile ore." },
    IRON_INGOT = { "Lingote de ferro", "Iron Ingot", "Um lingote de metal muito útil.", "A useful metal ingot." },
    GOLD_DUST = { "Pó de ouro", "Gold Dust", "Pequenas partículas de ouro.", "Tiny particles of gold." },
    GOLD_ORE = { "Minério de ouro", "Gold Ore", "Contém pequenas quantidades de ouro.", "Contains traces of gold." },
    GOLD_INGOT = { "Barra de ouro", "Gold Bar", "Uma barra de ouro puro.", "A bar of refined gold." },
    JUNK_DUST = { "Pó metálico impuro", "Impure Metal Dust", "Resultado de uma fundição mal executada.", "The result of poor smelting." },
    BRONZE_INGOT = { "Lingote de bronze", "Bronze Ingot", "Uma liga resistente de cobre e ferro.", "A durable copper and iron alloy." },
    ADAMANTIUM_INGOT = { "Lingote de adamantium", "Adamantium Ingot", "Um metal raro para trabalhos avançados.", "A rare metal for advanced crafting." },
    MOONGLASS_INGOT = { "Lingote de vidro lunar", "Moonglass Ingot", "Brilha com uma luz lunar misteriosa.", "Shimmers with mysterious lunar light." },
    REDGEM_SHARD = { "Fragmento de gema vermelha", "Red Gem Shard", "Um fragmento quente e avermelhado.", "A warm, reddish gem fragment." },
    BLUEGEM_SHARD = { "Fragmento de gema azul", "Blue Gem Shard", "Um fragmento frio e azulado.", "A cool, blue gem fragment." },
    GREENGEM_SHARD = { "Fragmento de gema verde", "Green Gem Shard", "Um fragmento cheio de energia.", "A lively gem fragment." },
    YELLOWGEM_SHARD = { "Fragmento de gema amarela", "Yellow Gem Shard", "Um fragmento de brilho intenso.", "A brightly glowing fragment." },
    ORANGEGEM_SHARD = { "Fragmento de gema laranja", "Orange Gem Shard", "Um fragmento de energia peculiar.", "A peculiar fragment of energy." },
    PURPLEGEM_SHARD = { "Fragmento de gema roxa", "Purple Gem Shard", "Um fragmento de aparência sinistra.", "An eerie-looking fragment." },
}

for key, entry in pairs(ITEMS) do
    STRINGS.NAMES[key] = L(entry[1], entry[2])
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[key] = L(entry[3], entry[4])
end

local CRAFTABLES =
{
    WARWORKBENCH = {
        name = { "Bancada de Guerra", "War Bench" },
        description = { "Sinto-me inspirado.", "I feel inspired." },
        recipe = { "Alguém trabalhou aqui. Ainda está quente...", "Someone worked on this, still hot..." },
    },
    CRAFTBOOK = {
        name = { "Livro de Projetos", "Craftbook" },
        description = { "Um caderno científico!", "A scientific notebook!" },
        recipe = { "Anos de experiência em forma de livro.", "Years of experience, in book form." },
    },
    MARBLE_CHEST = {
        name = { "Baú de Mármore", "Marble Chest" },
        description = { "É bem espaçoso por dentro.", "It's quite roomy in there." },
        recipe = { "Proteção à prova de fogo para seus pertences.", "Fire-proof protection for your hot goods." },
    },
    COLD_SAFE = {
        name = { "Cofre Refrigerado", "Cold Storage" },
        description = { "Nada é tão seguro quanto um cofre.", "Nothing as safe as a safe." },
        recipe = { "Mantimentos bem protegidos.", "Safe and secure sustenance." },
    },
    METAL_STORAGE_CHEST = {
        name = { "Baú de Metais", "Metal Storage Chest" },
        description = { "Um lugar seguro para meus metais.", "A safe place for my metals." },
        recipe = { "Um baú reforçado para minérios, pós, lingotes e materiais de fundição.", "A reinforced chest for ores, dusts, ingots and smelting materials." },
    },
    METAL_SMELTER = {
        name = { "Fundição de metais", "Metal Smelter" },
        description = { "Uma estrutura para fundir e refinar metais.", "A station for smelting and refining metals." },
        recipe = { "Derreta e refine diferentes metais.", "Smelt and refine different metals." },
    },
    MAM_STONE_CHISEL = {
        name = { "Cinzel de Entalhe em Pedra", "Stone-Carving Chisel" },
        description = { "Reutilizável para trabalhar pedra. Não se desgasta ao fabricar.", "Reusable for stoneworking. Crafting does not wear it down." },
        recipe = { "Uma ferramenta reutilizável para trabalhar pedra.", "A reusable tool for cutting stone." },
    },
    METALLURGY_REFERENCE_BOOK = {
        name = { "Guia de Metalurgia", "Metallurgy Guide" },
        description = { "Conhecimento sobre minérios, ligas e fundição.", "A field guide to ores, alloys and smelting." },
        recipe = { "Um guia de campo sobre minérios, ligas e fundição.", "A field guide to ores, alloys and smelting." },
    },
}

for key, entry in pairs(CRAFTABLES) do
    STRINGS.NAMES[key] = L(entry.name[1], entry.name[2])
    STRINGS.RECIPE_DESC[key] = L(entry.recipe[1], entry.recipe[2])
    STRINGS.CHARACTERS.GENERIC.DESCRIBE[key] = L(entry.description[1], entry.description[2])
end

STRINGS.ACTIONS.OPEN_CRAFTING.WARWORKBENCH = L("Fabricar na", "Craft at")
STRINGS.ACTIONS.OPEN_CRAFTING.CRAFTBOOK = L("Consultar", "Read")

STRINGS.RECIPE_DESC.MAM_AXE_BOARDS = L("Requer um machado funcional; a ferramenta não é consumida.",
    "Requires a working axe; the tool is not consumed.")
STRINGS.RECIPE_DESC.MAM_CHISEL_CUTSTONE = L("Requer um Cinzel de Entalhe em Pedra reutilizável.",
    "Requires a reusable Stone-Carving Chisel.")
STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.BUILD.MAM_NEEDS_AXE = L("Preciso carregar um machado que funcione.",
    "I need to carry a working axe.")
STRINGS.CHARACTERS.GENERIC.ACTIONFAIL.BUILD.MAM_NEEDS_CHISEL = L("Preciso carregar meu cinzel de entalhe em pedra.",
    "I need to carry my stone-carving chisel.")

STRINGS.NAMES.IRONROCK = L("Depósito de ferro", "Iron Deposit")
STRINGS.NAMES.SPIKYROCK = L("Depósito de cobre", "Copper Deposit")
