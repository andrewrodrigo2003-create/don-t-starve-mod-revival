-- Disponibiliza _G para os arquivos carregados via modimport (o ambiente do mod so tem GLOBAL).
env._G = GLOBAL
STRINGS = GLOBAL.STRINGS
RECIPETABS = GLOBAL.RECIPETABS
Recipe = GLOBAL.Recipe
Ingredient = GLOBAL.Ingredient
TECH = GLOBAL.TECH
local require = GLOBAL.require
local TUNING = GLOBAL.TUNING
local ACTIONS = GLOBAL.ACTIONS
local Action = GLOBAL.Action
local Builder = require "components/builder"
local AllRecipes = GLOBAL.AllRecipes
local CUSTOM_RECIPETABS = GLOBAL.CUSTOM_RECIPETABS
local GetValidRecipe = GLOBAL.GetValidRecipe
local RECIPETABS = GLOBAL.RECIPETABS
require("recipes")

Assets = {

	Asset("ATLAS", "images/hud/wretchtab.xml"),

	Asset("IMAGE", "minimap/obsidian_workbench.tex"),
	Asset("ATLAS", "minimap/obsidian_workbench.xml"),
	Asset("ATLAS", "images/inventoryimages/obsidian_workbench.xml"),
	Asset("IMAGE", "images/inventoryimages/obsidian_workbench.tex"),

	Asset("SOUNDPACKAGE", "sound/halberdsound.fev"),
	Asset("SOUND", "sound/halberdsound.fsb"),
	Asset( "IMAGE", "images/inventoryimages/halberd.tex" ),
	Asset( "ATLAS", "images/inventoryimages/halberd.xml" ),
	Asset( "ATLAS_BUILD", "images/inventoryimages/halberd.xml", 256),
	Asset("IMAGE", "images/tfwp_inventoryimgs.tex"),
	Asset("ATLAS", "images/tfwp_inventoryimgs.xml"),
	Asset("ANIM", "anim/ui_largechest_5x5.zip"),

	Asset("ATLAS", "images/inventoryimages/marbleseed.xml"),
	Asset("ANIM", "anim/marbleseed.zip"),

	Asset("IMAGE", "images/inventoryimages/pig_scepter_images.tex"),
	Asset("ATLAS", "images/inventoryimages/pig_scepter_images.xml"),

	Asset("ANIM", "anim/sharkscale.zip"),
	Asset("IMAGE", "images/inventoryimages/sharkscale.tex"),
	Asset("ATLAS", "images/inventoryimages/sharkscale.xml"),
	Asset("ANIM", "anim/forkstick.zip"),
	Asset("ATLAS", "images/inventoryimages/forkstick.xml"),
	Asset("IMAGE", "images/inventoryimages/forkstick.tex"),
    	Asset("ATLAS", "images/inventoryimages/shears.xml"),
    	Asset("IMAGE", "images/inventoryimages/shears.tex"),
	Asset( "ATLAS_BUILD", "images/inventoryimages/shears.xml", 256),
    	Asset("ATLAS", "images/inventoryimages/donharpoon.xml"),
    	Asset("IMAGE", "images/inventoryimages/donharpoon.tex"),
	Asset( "ATLAS_BUILD", "images/inventoryimages/donharpoon.xml", 256),

	Asset("ANIM", "anim/player_actions_shear.zip"),

	Asset("SOUNDPACKAGE", "sound/dontstarve_DLC003.fev"), 
	--Asset( "SOUND", "sound/DLC003_sfx.fsb"),
	Asset( "ATLAS", "images/inventoryimages/willowdoll.xml" ),
	Asset( "IMAGE", "images/inventoryimages/willowdoll.tex" ),
	
	Asset("ATLAS", "images/inventoryimages/forginghammer.xml"),
	Asset("IMAGE", "images/inventoryimages/forginghammer.tex"),
	Asset("ATLAS", "images/inventoryimages/pithpike.xml"),
	Asset("IMAGE", "images/inventoryimages/pithpike.tex"),
	Asset("ATLAS", "images/inventoryimages/spiralspear.xml"),
	Asset("IMAGE", "images/inventoryimages/spiralspear.tex"),
	Asset("ATLAS", "images/tabimages/theforge_tab.xml"),
	Asset("IMAGE", "images/tabimages/theforge_tab.tex"),
}

-- Make every custom metal ingredient discoverable by vanilla GetInventoryItemAtlas.
-- This is used by crafting ingredient widgets, inventory previews and other UI.
if RegisterInventoryItemAtlas ~= nil then
    for _, item in ipairs({
        "copper_ore", "iron_ore",
        "copper_dust", "iron_dust", "gold_dust",
        "copper_ingot", "iron_ingot", "bronze_ingot",
        "gold_ingot", "moonglass_ingot", "adamantium_ingot", "junk_dust",
        "redgem_shard", "yellowgem_shard", "bluegem_shard",
        "purplegem_shard", "greengem_shard", "orangegem_shard",
    }) do
        RegisterInventoryItemAtlas("images/inventoryimages/" .. item .. ".xml", item .. ".tex")
    end
end

PrefabFiles = {
	"warworkbench",

	"forginghammerold", 
	"pithpikeold", 
	"blacksmith_edgeold", 

	"metal_dusts", 
	"metals", 
	"metal_smelter", 
	"gem_shards", 
	"newrocks",
	"goldore",
	"halberd",
	"jagged_armor",
	"tfwp_hats",
	"marble_chest",
	"cold_safe",
	"metal_storage_chest",
	"marbleseed",
	"scepter",
	"sharkscale",
	"forkstick",
	"shears",
	"craftbook",
	"metallurgy_reference_book",
	--"cursed_phantom",
	"cursed_piggy",
	"cursed_piggy_mask",
	"cursed_piggy_weapon",
	--"cursed_ghost_crown",
	"donharpoon",

	"dst_willowdoll",

	"forginghammer",
	"pithpike",
	"spiralspear",
	"blacksmith_edge",
	"weaponsparks_fx",
	"forgespear_fx",
}

-- Config primeiro: nenhum prefab, widget ou hook pode ser carregado antes dos
-- valores das opcoes estarem disponiveis via MAMConfig.
local MAMConfig = require("mam/config")
local MAMLog = require("mam/log")
MAMConfig.Init(GetModConfigData)

modimport("initialise/modded_actions.lua")
modimport("initialise/modded_cookers.lua")
modimport("initialise/modded_ui_forecast.lua")
modimport("initialise/modded_strings.lua")
modimport("initialise/modded_recipes.lua")
modimport("initialise/modded_regrow.lua")
modimport("initialise/modded_marbletrees.lua")
-- Depois de modded_marbletrees: o postinit de "marbletree" la' garante o
-- lootdropper, e os rolls de minerio precisam encontrar o componente criado.
modimport("initialise/modded_drops.lua")
modimport("initialise/modded_pithpikemove.lua")
modimport("initialise/modded_shearsharvest.lua")
modimport("initialise/modded_mace.lua")
modimport("initialise/modded_playerpost.lua")

if GetModConfigData("disablemapchanges") then
modimport("initialise/modded_map.lua")
end

modimport("post_initialise/post_inits.lua")
modimport("initialise/modded_stronger_bernie.lua")
modimport("initialise/modded_forgepack.lua")

AddMinimapAtlas("images/inventoryimages/metal_smelter.xml")
AddMinimapAtlas("images/mapicons/spikyrock.xml")
AddMinimapAtlas("images/mapicons/ironrock.xml")
AddMinimapAtlas("images/inventoryimages/willowdoll.xml")

	
local newtechtoadd = {"ALCHEMY", "CRAFTSBOOK"}
for _, v in pairs(newtechtoadd) do
    local thelower = v:lower()
    TechTree.AVAILABLE_TECH_BONUS[v] = thelower .. "_bonus"
    TechTree.AVAILABLE_TECH_TEMPBONUS[v] = thelower .. "_tempbonus"
    TechTree.AVAILABLE_TECH_BONUS_CLASSIFIED[v] = thelower .. "bonus"
    TechTree.AVAILABLE_TECH_TEMPBONUS_CLASSIFIED[v] = thelower .. "tempbonus"
    TechTree.AVAILABLE_TECH_LEVEL_CLASSIFIED[v] = thelower .. "level"
end

TUNING.PROTOTYPER_TREES.ALCHEMY_ONE = TechTree.Create({
    ALCHEMY = 1
})

TUNING.PROTOTYPER_TREES.CRAFTSBOOK_ONE = TechTree.Create({
    CRAFTSBOOK = 1
})

local function stamp_mam_tech(recipe)
    if recipe == nil or recipe.level == nil then
        return
    end
    if recipe.level.ALCHEMY == nil then
        recipe.level.ALCHEMY = 0
    end
    if recipe.level.CRAFTSBOOK == nil then
        recipe.level.CRAFTSBOOK = 0
    end
end

-- ALCHEMY e CRAFTSBOOK sao chaves de tecnologia novas criadas por este mod. Toda
-- receita precisa de uma entrada correspondente nelas (0 = nao desbloqueia nesta
-- bancada), senao a arvore de tecnologia fica com buraco.
--
-- O original fazia um unico `for pairs(AllRecipes)` aqui, em tempo de carga: receitas
-- registradas DEPOIS (por qualquer mod que carregue apos o nosso, ou por este proprio
-- mod em AddSimPostInit) ficavam sem as chaves -- a auditoria do Uncompromising Mode
-- Beta achou exatamente essa assimetria nos dois lados (init/init_recipes/init_recipes.lua:58-62
-- faz o mesmo truque para VETERANSHRINE, entao a completude dependia da ordem de carga).
-- AddRecipePostInitAny resolve isso: a funcao roda para as receitas ja existentes AGORA
-- e para cada Recipe nova construida, de qualquer mod (modutil.lua:601-609 e recipe.lua:168-174).
AddRecipePostInitAny(stamp_mam_tech)

-- Custom Prototyper and Recipe filters --
require("recipes_filter")

AddPrototyperDef("warworkbench", {
    icon_atlas = "images/tabimages/theforge_tab.xml",
    icon_image = "theforge_tab.tex",
    is_crafting_station = true,
    action_str = "WARWORKBENCH",
    filter_text = "War bench"
})

AddPrototyperDef("craftbook", {
    icon_atlas = "images/hud/wretchtab.xml",
    icon_image = "wretchtab.tex",
    is_crafting_station = true,
    action_str = "CRAFTBOOK",
    filter_text = "Craft book"
})

AddRecipe2("warworkbench", {Ingredient("cutstone", 5), Ingredient("iron_ingot", 3, "images/inventoryimages/iron_ingot.xml"), Ingredient("charcoal", 5)}, TECH.SCIENCE_TWO, { placer = "warworkbench_placer", min_spacing = 1, atlas = "images/inventoryimages/obsidian_workbench.xml", image = "obsidian_workbench.tex", }, {"PROTOTYPERS"})

-- Informational reference only: no prototyper, unlock, or remote crafting.
AddRecipe2("metallurgy_reference_book", {
    Ingredient("papyrus", 2), Ingredient("charcoal", 2),
    Ingredient("iron_ingot", 1, "images/inventoryimages/iron_ingot.xml"),
}, TECH.ALCHEMY_ONE, { image = "waxwelljournal.tex" }, { "CRAFTING_STATION" })

AddRecipe2("armor_sanity", {Ingredient("adamantium_ingot", 2, "images/inventoryimages/adamantium_ingot.xml"),Ingredient("papyrus", 3)}, TECH.ALCHEMY_ONE, {"CRAFTING_STATION"})

AddRecipe2("nightsword", {Ingredient("adamantium_ingot", 2, "images/inventoryimages/adamantium_ingot.xml"),Ingredient("livinglog", 1)}, TECH.ALCHEMY_ONE, {"CRAFTING_STATION"})

AddRecipe2("marble_chest", {Ingredient("marble", 5), Ingredient("gold_ingot", 2, "images/inventoryimages/gold_ingot.xml"), Ingredient("cutstone", 3)}, TECH.ALCHEMY_ONE, {placer = "marble_chest_placer", min_spacing=0.5, image="treasurechest_sacred.tex"}, {"CRAFTING_STATION", "CONTAINERS"})

AddRecipe2("cold_safe", {Ingredient("gears", 1), Ingredient("iron_ingot", 3, "images/inventoryimages/iron_ingot.xml"), Ingredient("bluegem", 1)}, TECH.ALCHEMY_ONE, {placer = "cold_safe_placer", min_spacing=0.5, image="icebox_victorian.tex"}, {"CRAFTING_STATION", "COOKING"})

-- metal_storage_chest permanece registrado apenas para compatibilidade com saves antigos;
-- não há receita para construí-lo em mundos novos.

AddRecipe2("jagged_armor", {Ingredient("houndstooth", 4), Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml"), Ingredient("armormarble", 1), Ingredient("iron_ingot", 3, "images/inventoryimages/iron_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, image = "lavaarena_armor_hpdamager.tex"}, {"CRAFTING_STATION"})

AddRecipe2("tfwp_luxury_nox_helm_hat", {Ingredient("footballhat", 1), Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml"), Ingredient("walrus_tusk", 1)}, TECH.ALCHEMY_ONE, {nounlock = true, atlas = "images/inventoryimages.xml", image="lavaarena_crowndamagerhat.tex"}, {"CRAFTING_STATION"})

AddRecipe2("halberd", {Ingredient("log", 2), Ingredient("iron_ingot", 3, "images/inventoryimages/iron_ingot.xml"), Ingredient("rope", 1) }, TECH.ALCHEMY_ONE, {nounlock = true, atlas="images/inventoryimages/halberd.xml", image="halberd.tex"}, {"CRAFTING_STATION"})

AddRecipe2("scepter", {Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml"), Ingredient("purplegem", 1), Ingredient("livinglog", 2)}, TECH.ALCHEMY_ONE, {nounlock = true, atlas="images/inventoryimages/pig_scepter_images.xml", image="pig_scepter_images.tex"}, {"CRAFTING_STATION"})

AddRecipe2("forkstick", {Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml"), Ingredient("sharkscale", 3, "images/inventoryimages/sharkscale.xml"), Ingredient("gnarwail_horn", 1)}, TECH.ALCHEMY_ONE,{nounlock = true, atlas="images/inventoryimages/forkstick.xml", image="forkstick.tex"}, {"CRAFTING_STATION"}) 

AddRecipe2("shears", {Ingredient("log",1), Ingredient("flint",2), Ingredient("iron_ingot", 2, "images/inventoryimages/iron_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, atlas = "images/inventoryimages/shears.xml", image="shears.tex"}, {"CRAFTING_STATION"})

AddRecipe2("donharpoon", {Ingredient("marble",2), Ingredient("flint",3), Ingredient("iron_ingot", 2, "images/inventoryimages/iron_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, atlas = "images/inventoryimages/donharpoon.xml", image="donharpoon.tex"}, {"CRAFTING_STATION"})

AddRecipe2("dst_willowdoll", 
{Ingredient("beefalowool", 4), Ingredient("sewing_kit", 1), Ingredient("charcoal", 10)}, TECH.CRAFTSBOOK_ONE, {nounlock = true, atlas="images/inventoryimages/willowdoll.xml", image="willowdoll.tex"}, {"CRAFTING_STATION"})

STRINGS.RECIPE_DESC.DST_WILLOWDOLL = "A firey cute doll!"
STRINGS.NAMES.DST_WILLOWDOLL = "Willow Doll"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.DST_WILLOWDOLL = "I feel warm just looking at it!"

STRINGS.NAMES.SHEARS = "Harvest shears"
STRINGS.RECIPE_DESC.SHEARS = "No Stressed Out!"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SHEARS = "Now I can harvest easily."

STRINGS.NAMES.FORKSTICK = "Poseidon's trident"
STRINGS.RECIPE_DESC.FORKSTICK = "Deep Sea legend"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.FORKSTICK = "I wonder how old this artifact is"
STRINGS.CHARACTERS.WENDY.DESCRIBE.FORKSTICK = "The people that forged this have long dead"

STRINGS.NAMES.SHARKSCALE = "Shark Scale"
--STRINGS.RECIPE_DESC.SCEPTER = "Yes, sharks have scales."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SCEPTER = "I had one in my nature collection."

STRINGS.NAMES.SCEPTER = "Regal Scepter"
STRINGS.RECIPE_DESC.SCEPTER = "A symbol of leadership."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.SCEPTER = "The symbol of a peple`s burden."

STRINGS.NAMES.HALBERD = "Halberd"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.HALBERD = "Now I can't be caught off-guard."
STRINGS.RECIPE_DESC.HALBERD = "Pointy and hurty."

--STRINGS.NAMES.TFWP_LUXURY_NOX_HELM_HAT = STRINGS.NAMES.LAVAARENA_CROWNDAMAGERHAT
STRINGS.NAMES.TFWP_LUXURY_NOX_HELM_HAT = "Resplendent Nox Helm"
STRINGS.RECIPE_DESC.TFWP_LUXURY_NOX_HELM_HAT = "Protection, Cool."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.TFWP_LUXURY_NOX_HELM_HAT = "Sturdy and cool lookin'"
--STRINGS.CHARACTERS.GENERIC.DESCRIBE.TFWP_LUXURY_NOX_HELM_HAT = STRINGS.CHARACTERS.GENERIC.DESCRIBE.LAVAARENA_CROWNDAMAGERHAT

STRINGS.NAMES.JAGGED_ARMOR = "Jagged Grand Armor"
STRINGS.RECIPE_DESC.JAGGED_ARMOR = "Hope it lasts"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.JAGGED_ARMOR = "Shine in power!"
--STRINGS.CHARACTERS.GENERIC.DESCRIBE.JAGGED_ARMOR = STRINGS.CHARACTERS.GENERIC.DESCRIBE.LAVAARENA_ARMOR_HPDAMAGER

STRINGS.NAMES.WARWORKBENCH = "Armory"
STRINGS.RECIPE_DESC.WARWORKBENCH = "Someone worked on this, still hot..."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.WARWORKBENCH = "I feel inspired."

STRINGS.RECIPE_DESC.MARBLE_CHEST = "Fire-proof protection for your hot goods."
STRINGS.NAMES.MARBLE_CHEST = "Marble Chest"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.MARBLE_CHEST = "It's quite roomy in there."

STRINGS.RECIPE_DESC.COLD_SAFE = "Safe and secure sustenance."
STRINGS.NAMES.COLD_SAFE = "Cold Storage"
STRINGS.NAMES.METAL_STORAGE_CHEST = "Metal Storage Chest"
STRINGS.RECIPE_DESC.METAL_STORAGE_CHEST = "A reinforced chest for ores, dusts, ingots and smelting materials."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.COLD_SAFE = "Nothing as safe as a safe."

STRINGS.NAMES.CRAFTBOOK = "Craftbook"
STRINGS.RECIPE_DESC.CRAFTBOOK = "Years of experience, in book form."
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CRAFTBOOK = "A scientific notebook!"





if GetModConfigData("forge_weapons") then

AddRecipe2("forginghammer", {Ingredient("hammer", 1), Ingredient("lightninggoathorn", 1), Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, image="hammer_mjolnir.tex"}, {"CRAFTING_STATION"})

AddRecipe2("pithpike", {Ingredient("lightninggoathorn", 2), Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml"), Ingredient("houndstooth", 3)}, TECH.ALCHEMY_ONE, {nounlock = true, image="spear_gungnir.tex"}, {"CRAFTING_STATION"})

AddRecipe2("spiralspear", {Ingredient("marble", 3),Ingredient("pithpike", 1, "images/inventoryimages/pithpike.xml"),  Ingredient("townportaltalisman", 2)}, TECH.ALCHEMY_ONE, {nounlock = true, image="spear_lance.tex"}, {"CRAFTING_STATION"})

AddRecipe2("blacksmith_edge", {Ingredient("marble", 5),Ingredient("driftwood_log", 2),  Ingredient("gold_ingot", 3, "images/inventoryimages/gold_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, image="lavaarena_heavyblade.tex"}, {"CRAFTING_STATION"})

--[[
local function MarbleWeapon(inst)
	inst:AddTag("marble")
	inst:AddTag("knockback_protection")
	--inst:AddTag("stronggrip")
end
AddPrefabPostInit("blacksmith_edge", MarbleWeapon)
]]

else

AddRecipe2("forginghammerold", {Ingredient("twigs", 4), Ingredient("marble", 2), Ingredient("gold_ingot", 1, "images/inventoryimages/gold_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, image="hammer_mjolnir.tex"}, {"CRAFTING_STATION"})

AddRecipe2("pithpikeold", {Ingredient("marble", 2), Ingredient("gold_ingot", 1, "images/inventoryimages/gold_ingot.xml"), Ingredient("houndstooth", 3)}, TECH.ALCHEMY_ONE, {nounlock = true, image="spear_gungnir.tex"}, {"CRAFTING_STATION"})

AddRecipe2("blacksmith_edgeold", {Ingredient("marble", 4),Ingredient("driftwood_log", 2),  Ingredient("gold_ingot", 1, "images/inventoryimages/gold_ingot.xml")}, TECH.ALCHEMY_ONE, {nounlock = true, image="lavaarena_heavyblade.tex"}, {"CRAFTING_STATION"})

AddStategraphPostInit("wilson", function(self)
    local onenter = self.states.hit.onenter
    self.states.hit.onenter = function(inst, ...)
        if inst:HasTag("parrying") then 
	    return inst.sg:GoToState("parry_pre") 
        else 
	    return onenter(inst, ...) 
        end
    end 
end)

end

STRINGS.RECIPE_DESC.FORGINGHAMMEROLD = "Heavy Hammer"
STRINGS.NAMES.FORGINGHAMMEROLD = "Forging Hammer"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.FORGINGHAMMEROLD = "Works on moles too."

STRINGS.RECIPE_DESC.PITHPIKEOLD = "A not-so-straight spear."
STRINGS.NAMES.PITHPIKEOLD = "Pith Pike"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.PITHPIKEOLD = "Which end goes where?"

STRINGS.RECIPE_DESC.BLACKSMITH_EDGEOLD = "A super large sword for epic sized fun."
STRINGS.NAMES.BLACKSMITH_EDGEOLD = "Blacksmith's Edge"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.BLACKSMITH_EDGEOLD = "Now that's a work of art!"

local containers = require "containers"
local MAMSmelting = require "smelting"
local MAMMetalStorage = require "mam/metal_storage"

local params = {}

local containers_widgetsetup_base = containers.widgetsetup
function containers.widgetsetup(container, prefab, data, ...)
    local t = params[prefab or container.inst.prefab]
    if t ~= nil then
        for k, v in pairs(t) do
            container[k] = v
        end
        container:SetNumSlots(container.widget.slotpos ~= nil and #container.widget.slotpos or 0)
    else
        containers_widgetsetup_base(container, prefab, data, ...)
    end
end

local function makeChest()
    local container =
    {
        widget =
        {
            slotpos = {},
            animbank = "ui_largechest_5x5",
            animbuild = "ui_largechest_5x5",
            pos = GLOBAL.Vector3(0, 200, 0),
            side_align_tip = 160,
        },
        type = "chest",
    }

    for y = 3, -1, -1 do
        for x = -1, 3 do
            table.insert(container.widget.slotpos, GLOBAL.Vector3(80 * x - 80 * 2 + 80, 80 * y - 80 * 2 + 80, 0))
        end
    end

    return container
end

params.marble_chest = makeChest()
params.cold_safe = makeChest()
params.metal_storage_chest = makeChest()

-- O filtro usa a lista real de ingredientes e a tabela de produtos da forja.
-- Assim aceita minérios, poeiras, fragmentos, lingotes e ligas registradas.
params.metal_storage_chest.itemtestfn =
    MAMMetalStorage.MakeItemTestFn(MAMSmelting.IsSmelterIngredient, MAMSmelting.recipes.metal_smelter)

function params.cold_safe.itemtestfn(container, item, slot)
    if item:HasTag("icebox_valid") then
        return true
    end

    --Perishable
    if not (item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled")) then
        return false
    end

    --Edible
    for k, v in pairs(GLOBAL.FOODTYPE) do
        if item:HasTag("edible_"..v) then
            return true
        end
    end

    return false
end

for k, v in pairs(params) do
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end

-- O loot do arbusto de marmore (iron_ore por estagio) foi para
-- initialise/modded_drops.lua: la' ele encadeia o lootsetupfn vivo em vez de
-- substitui-lo, e pode ser desligado por fonte. O AddComponent("lootdropper")
-- incondicional que existia aqui tambem sumiu -- o vanilla ja' cria o componente
-- (prefabs/marbleshrub.lua:193) e AddComponent repetido imprime aviso com
-- debugstack a cada arbusto que nasce (entityscript.lua:604-618).

GLOBAL.FUELTYPE.OSSIFY = "OSSIFY"
AddPrefabPostInit("gold_dust", function (inst)
	if not GLOBAL.TheWorld.ismastersim then
		return inst
	end
	inst:AddComponent("fuel")
    inst.components.fuel.fuelvalue = (400)	--100

    inst.components.fuel.fueltype = GLOBAL.FUELTYPE.OSSIFY
end)

-------------------------------

-- sharkscale do tubarao: mesma historia, fonte "shark" em modded_drops.lua.
-- O UM Beta acrescenta rockjawleather ao mesmo prefab por AddChanceLoot
-- (postinit/prefabs/shark.lua:9); os dois rolls convivem sem se sobrescrever.

TUNING.SHARK_SPAWN_CHANCE = 0.5		--0.075
TUNING.GNARWAIL_SPAWN_CHANCE = 0.5	--0.075

--[[
AddPrefabPostInit("world", function(world)
	SetSharedLootTable('walrus', {
		{'meat',            1},
		{'blowdart_pipe',   1},
		{'walrushat',       1},
		{'walrus_tusk',     1},
	})
end)
]]

AddPrefabPostInit("goldenaxe", function(inst)
	local function onequipgold(inst, owner)
	    local skin_build = inst:GetSkinBuild()
	    if skin_build ~= nil then
	        owner:PushEvent("equipskinneditem", inst:GetSkinName())
	        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_goldenaxe", inst.GUID, "swap_goldenaxe")
	    else
	        owner.AnimState:OverrideSymbol("swap_object", "swap_goldenaxe", "swap_goldenaxe")
 	   end
	    owner.SoundEmitter:PlaySound("dontstarve/wilson/equip_item_gold")
	    owner.AnimState:Show("ARM_carry")
	    owner.AnimState:Hide("ARM_normal")
		owner:AddTag("woodcutter")
	end

	local function onunequip(inst, owner)
	    owner.AnimState:Hide("ARM_carry")
	    owner.AnimState:Show("ARM_normal")
	    local skin_build = inst:GetSkinBuild()
 	   if skin_build ~= nil then
	        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	    end
		owner:RemoveTag("woodcutter")
	end
	if not GLOBAL.TheWorld.ismastersim then
	       	return inst
	end
	inst.components.tool:SetAction(ACTIONS.CHOP, 2)
	inst.components.equippable:SetOnEquip(onequipgold)
	inst.components.equippable:SetOnUnequip(onunequip)
end)

AddPrefabPostInit("goldenshovel", function(inst)
	local DIG_TAGS = {"DIG_workable"}
	local DIG_NOT_TAGS = {"INLIMBO"}

	local function FinishedWork(owner, data)
		local x, y, z = owner.Transform:GetWorldPosition()
		owner:ShakeCamera(CAMERASHAKE.SIDE, 1, 0.02, 0.25)
		owner.SoundEmitter:PlaySound("hookline_2/creatures/boss/crabking/ice_attack", nil, 0.5)
		local ents = TheSim:FindEntities(x, y, z, 6, DIG_TAGS, DIG_NOT_TAGS)
		for k, v in pairs(ents) do
			if (v.prefab == data.target.prefab or v:HasTag("stump") and data.target:HasTag("stump")) and v.components.workable and
				v.components.workable:CanBeWorked() and
				v.components.workable:GetWorkAction() == ACTIONS.DIG then
				v.components.workable:WorkedBy(owner, 1)
				SpawnPrefab("shovel_dirt").Transform:SetPosition(v.Transform:GetWorldPosition())
			end
		end
	end

	local function onequipgold(inst, owner)
	    local skin_build = inst:GetSkinBuild()
	    if skin_build ~= nil then
	        owner:PushEvent("equipskinneditem", inst:GetSkinName())
	        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_goldenshovel", inst.GUID, "swap_goldenpickaxe")
	    else
	        owner.AnimState:OverrideSymbol("swap_object", "swap_goldenshovel", "swap_goldenshovel")
	    end
	    owner.SoundEmitter:PlaySound("dontstarve/wilson/equip_item_gold")
	    owner.AnimState:Show("ARM_carry")
	    owner.AnimState:Hide("ARM_normal")

		inst:ListenForEvent("working", FinishedWork, owner)
	end

	local function onunequip(inst, owner)
	    owner.AnimState:Hide("ARM_carry")
	    owner.AnimState:Show("ARM_normal")
	    local skin_build = inst:GetSkinBuild()
	    if skin_build ~= nil then
	        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
	    end
		inst:RemoveEventCallback("working", FinishedWork, owner)
	end
	
	if not GLOBAL.TheWorld.ismastersim then
	       	return inst
	end
	--inst:AddInherentAction(ACTIONS.DIG)
	inst.components.equippable:SetOnEquip(onequipgold)
	inst.components.equippable:SetOnUnequip(onunequip)
end)

if GetModConfigData("cookbookcook") then
AddPrefabPostInit("cookbook", function(inst)
	local assets =
	{
	    Asset("ANIM", "anim/cookbook.zip"),
	    Asset("ANIM", "anim/swap_book_maxwell.zip"),
	}

	local function onequip(inst, owner)
		owner.AnimState:OverrideSymbol("book_closed", "swap_book_maxwell", "book_closed")
		owner.AnimState:Hide("ARM_carry")
		owner:AddTag("masterchef")
		owner:AddTag("professionalchef")
	end

	local function onunequip(inst, owner)
		owner.AnimState:ClearOverrideSymbol("swap_object")
		owner.AnimState:Hide("ARM_carry")
		owner.AnimState:Show("ARM_normal")
		owner:RemoveTag("masterchef")
		owner:RemoveTag("professionalchef")
	end

	if not GLOBAL.TheWorld.ismastersim then
       		return inst
	end

	inst:AddTag("cookingbook")

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(onequip)
	inst.components.equippable:SetOnUnequip(onunequip)
end)

AddPrefabPostInit("cookpot", function(inst)
	if not GLOBAL.TheWorld.ismastersim then
       		return inst
	end
    inst:AddTag("mastercookware")
end)

modimport("scripts/cookingbook_stategraph.lua")
modimport("scripts/players_stategraph.lua")
end



if GetModConfigData("craftingbook") then
modimport("initialise/modded_craftbook.lua")
end



TUNING.TOT = require("tot_tuning")

--[[
STRINGS.NAMES.CURSED_PHANTOM            = "Phantom"
STRINGS.NAMES.CURSED_PHANTOM_FRIENDLY   = "Friendly Phantom"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_PHANTOM                 = "Do I know you? I do!"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_PHANTOM_FRIENDLY        = "Do I know you? I do!"

AddPrefabPostInit("crawlinghorror", function(inst)
if GLOBAL.TheWorld.ismastersim then
inst.components.lootdropper:AddChanceLoot("cursed_phantom", 0.2)
inst.components.lootdropper:AddChanceLoot("cursed_phantom", 0.2)
inst.components.lootdropper:AddChanceLoot("cursed_phantom", 0.2)
inst.components.lootdropper:AddChanceLoot("cursed_phantom", 0.2)
inst.components.lootdropper:AddChanceLoot("cursed_phantom", 0.2)
end
end)
]]

STRINGS.NAMES.CURSED_PIGGY_WEAPON       = "Killer's Spike"
STRINGS.NAMES.CURSED_PIGGY_MASK         = "Killer's Mask"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_PIGGY_WEAPON            = "It's pointy!"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_PIGGY_MASK              = "What a scary mask!"
--STRINGS.NAMES.CURSED_GHOST_CROWN        = "The Fallen Crown"
--STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_GHOST_CROWN             = "It's a... thing?"

STRINGS.NAMES.CURSED_PIGGY = "Killer"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.CURSED_PIGGY = "I didn't think pigs could grow THAT much."

STRINGS.CURSED_PIGGY_TALK_FIGHT = {
    "I'LL KILL NOW!",
	"GET HERE!",
	"DON'T TRY TO RUN AWAY!",
	"NOWHERE TO HIDE!",
	"CHOP CHOP! I'M GONNA GET YA",
}

env._G = GLOBAL
_G.fns = require("fns")

modimport("scripts/tot_ui.lua")
