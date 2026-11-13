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
    METAL_SMELTER = {
        name = { "Fundição de metais", "Metal Smelter" },
        description = { "Uma estrutura para fundir e refinar metais.", "A station for smelting and refining metals." },
        recipe = { "Derreta e refine diferentes metais.", "Smelt and refine different metals." },
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

STRINGS.NAMES.IRONROCK = L("Depósito de ferro", "Iron Deposit")
STRINGS.NAMES.SPIKYROCK = L("Depósito de cobre", "Copper Deposit")
