name = "Metals and More Reforged"
description = "Create armor and weapons at your new craftable workbench."
author = "NevilleDST"
version = "2.9.5"
forumthread = ""

api_version = 10
--priority = -11
icon_atlas = "modicon.xml"
icon = "modicon.tex"

reign_of_giants_compatible = false
dont_starve_compatible = false
dst_compatible = true

all_clients_require_mod = true
client_only_mod = false

configuration_options = {
	{
        name = "craftingbook",
        label = "Crafting book",
		hover = "If enabled, you'll need the book to craft clothing items (backpacks, etc.) and some other recipes",
        options = 
        {
			{description = "Off", data = false},
			{description = "On", data = true},
        }, 
        default = false,
	},
	{
        name = "cookbookcook",
        label = "Cookbook cooking",
		hover = "If enabled, you'll need the Cookbook equipped to be able to cook.",
        options = 
        {
			{description = "Off", data = false},
			{description = "On", data = true},
        }, 
        default = false,
	},
	{
        name = "Disable Normal Map",
        label = "Map survival",
		hover = "If enabled, You need to equip the compass to access the map.",
        options = 
        {
			{description = "Off", data = false},
			{description = "On", data = true},
        }, 
        default = false,
	},
	{
        name = "disablemapchanges",
        label = "Using Minimap mod?",
		hover = "If you choose OFF, it's safe to use Minimap mod.",
        options = 
        {
			{description = "Off", data = false},
			{description = "On", data = true},
        }, 
        default = false,
	},
----------------------------------------------
	{
		name = "Global Weapons options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "forge_weapons",
        label = "Old vs New Forge weapons",
		hover = "If enabled, you'll have Forge weapons and their abilities from the Event.",
        options = 
        {
			{description = "Off - Give me old weapons.", data = false},
			{description = "On - Give me those abilities.", data = true},
        }, 
        default = false,
	},
------------------------------------------------
	{
		name = "Global Forge options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "PREVENT_COMPAGNION_ATTACK",
		label = "Disable compagnion attack",
		hover = "Prevent compagnions to be attacked by players",
		options = {
			{description = "No", data = false},
			{description = "Yes", data = true},
		},
		default = false,
	},
	-- Forging hammer
	{
		name = "Forging Hammer options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "FORGING_HAMMER_DISABLE_RECIPE",
		label = "Disable recipe",
		hover = "You can still get this item by using console command.",
		options = {
			{description = "No", data = false},
			{description = "Yes", data = true},
		},
		default = false,
	},
	{
		name = "FORGINGHAMMER_DAMAGE",
		label = "Damages",
		options = {
			{description = "5", data = 5},
			{description = "10", data = 10},
			{description = "15", data = 15},
			{description = "20 (default)", data = 20},
			{description = "25", data = 25},
			{description = "30", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
		},
		default = 20,
	},
	{
		name = "FORGINGHAMMER_ALT_DAMAGE",
		label = "Special damages",
		options = {
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25", data = 25},
			{description = "30 (default)", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
			{description = "55", data = 55},
			{description = "60", data = 60},
			{description = "80", data = 80},
			{description = "100", data = 100},
		},
		default = 30,
	},
	{
		name = "FORGING_HAMMER_DURABILITY",
		label = "Durability",
		options = {
			{description = "Infinite", data = 0},
			{description = "100 Uses", data = 100},
			{description = "200 Uses", data = 200},
			{description = "300 Uses", data = 300},
			{description = "400 Uses", data = 400},
			{description = "500 Uses", data = 500},
			{description = "750 Uses", data = 750},
			{description = "1000 Uses", data = 1000},
			{description = "1500 Uses", data = 1500},
			{description = "2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "FORGING_HAMMER_DURABILITY_NORMAL",
		label = "Normal consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1/Use", data = 1},
			{description = "2/Use", data = 2},
			{description = "3/Use", data = 3},
			{description = "4/Use", data = 4},
			{description = "5/Use", data = 5},
			{description = "10/Use", data = 10},
			{description = "15/Use", data = 15},
			{description = "20/Use", data = 20},
			{description = "25/Use", data = 25},
			{description = "30/Use", data = 30},
			{description = "35/Use", data = 35},
			{description = "40/Use", data = 40},
			{description = "45/Use", data = 45},
			{description = "50/Use", data = 50},
		},
		default = 1,
	},
	{
		name = "FORGING_HAMMER_DURABILITY_SPECIAL",
		label = "Special consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1%", data = 1},
			{description = "2%", data = 2},
			{description = "3%", data = 3},
			{description = "4%", data = 4},
			{description = "5%", data = 5},
			{description = "10%", data = 10},
			{description = "15%", data = 15},
			{description = "20%", data = 20},
			{description = "25%", data = 25},
			{description = "30%", data = 30},
			{description = "35%", data = 35},
			{description = "40%", data = 40},
			{description = "45%", data = 45},
			{description = "50%", data = 50},
		},
		default = 5,
	},
	{
		name = "FORGING_HAMMER_COOLDOWN",
		label = "Cooldown",
		options = {
			{description = "-75%", data = 3},
			{description = "-50%", data = 9},
			{description = "-25%", data = 13.5},
			{description = "-10%", data = 16.2},
			{description = "Default (18s)", data = 18},
			{description = "+10%", data = 19.8},
			{description = "+25%", data = 22.5},
			{description = "+50%", data = 27},
			{description = "+75%", data = 31.5},
			{description = "+100%", data = 36},
		},
		default = 18,
	},
	-- Pith pike
	{
		name = "Pith Pike options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "PITHPIKE_DISABLE_RECIPE",
		label = "Disable recipe",
		hover = "You can still get this item by using console command.",
		options = {
			{description = "No", data = false},
			{description = "Yes", data = true},
		},
		default = false,
	},
	{
		name = "PITHPIKE_DAMAGE",
		label = "Damages",
		options = {
			{description = "10", data = 10},
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25 (default)", data = 25},
			{description = "30", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
			{description = "55", data = 55},
		},
		default = 25,
	},
	{
		name = "PITHPIKE_ALT_DAMAGE",
		label = "Special damages",
		options = {
			{description = "10", data = 10},
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25 (default)", data = 25},
			{description = "30", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
			{description = "55", data = 55},
			{description = "60", data = 60},
			{description = "65", data = 65},
			{description = "70", data = 70},
			{description = "75", data = 75},
			{description = "80", data = 80},
			{description = "85", data = 85},
		},
		default = 25,
	},
	{
		name = "PITHPIKE_DURABILITY",
		label = "Durability",
		options = {
			{description = "Infinite", data = 0},
			{description = "100 Uses", data = 100},
			{description = "200 Uses", data = 200},
			{description = "300 Uses", data = 300},
			{description = "400 Uses", data = 400},
			{description = "500 Uses", data = 500},
			{description = "750 Uses", data = 750},
			{description = "1000 Uses", data = 1000},
			{description = "1500 Uses", data = 1500},
			{description = "2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "PITHPIKE_DURABILITY_NORMAL",
		label = "Normal consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1/Use", data = 1},
			{description = "2/Use", data = 2},
			{description = "3/Use", data = 3},
			{description = "4/Use", data = 4},
			{description = "5/Use", data = 5},
			{description = "10/Use", data = 10},
			{description = "15/Use", data = 15},
			{description = "20/Use", data = 20},
			{description = "25/Use", data = 25},
			{description = "30/Use", data = 30},
			{description = "35/Use", data = 35},
			{description = "40/Use", data = 40},
			{description = "45/Use", data = 45},
			{description = "50/Use", data = 50},
		},
		default = 1,
	},
	{
		name = "PITHPIKE_DURABILITY_SPECIAL",
		label = "Special consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1%", data = 1},
			{description = "2%", data = 2},
			{description = "3%", data = 3},
			{description = "4%", data = 4},
			{description = "5%", data = 5},
			{description = "10%", data = 10},
			{description = "15%", data = 15},
			{description = "20%", data = 20},
			{description = "25%", data = 25},
			{description = "30%", data = 30},
			{description = "35%", data = 35},
			{description = "40%", data = 40},
			{description = "45%", data = 45},
			{description = "50%", data = 50},
		},
		default = 5,
	},
	{
		name = "PITHPIKE_COOLDOWN",
		label = "Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Default (12s)", data = 12},
			{description = "+10%", data = 14.4},
			{description = "+25%", data = 15},
			{description = "+50%", data = 18},
			{description = "+75%", data = 21},
			{description = "+100%", data = 24},
		},
		default = 12,
	},
	-- Spiral spear
	{
		name = "Spiral Spear options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "SPIRALSPEAR_DISABLE_RECIPE",
		label = "Disable recipe",
		hover = "You can still get this item by using console command.",
		options = {
			{description = "No", data = false},
			{description = "Yes", data = true},
		},
		default = false,
	},
	{
		name = "SPIRALSPEAR_DAMAGE",
		label = "Damages",
		options = {
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25", data = 25},
			{description = "30 (default)", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
			{description = "55", data = 55},
			{description = "60", data = 60},
		},
		default = 30,
	},
	{
		name = "SPIRALSPEAR_ALT_DAMAGE",
		label = "Special damages",
		options = {
			{description = "60", data = 60},
			{description = "65", data = 65},
			{description = "70", data = 70},
			{description = "75 (default)", data = 75},
			{description = "80", data = 80},
			{description = "85", data = 85},
			{description = "90", data = 90},
			{description = "95", data = 95},
			{description = "100", data = 100},
			{description = "110", data = 110},
			{description = "120", data = 120},
		},
		default = 75,
	},
	{
		name = "SPIRALSPEAR_DURABILITY",
		label = "Durability",
		options = {
			{description = "Infinite", data = 0},
			{description = "100 Uses", data = 100},
			{description = "200 Uses", data = 200},
			{description = "300 Uses", data = 300},
			{description = "400 Uses", data = 400},
			{description = "500 Uses", data = 500},
			{description = "750 Uses", data = 750},
			{description = "1000 Uses", data = 1000},
			{description = "1500 Uses", data = 1500},
			{description = "2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "SPIRALSPEAR_DURABILITY_NORMAL",
		label = "Normal consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1/Use", data = 1},
			{description = "2/Use", data = 2},
			{description = "3/Use", data = 3},
			{description = "4/Use", data = 4},
			{description = "5/Use", data = 5},
			{description = "10/Use", data = 10},
			{description = "15/Use", data = 15},
			{description = "20/Use", data = 20},
			{description = "25/Use", data = 25},
			{description = "30/Use", data = 30},
			{description = "35/Use", data = 35},
			{description = "40/Use", data = 40},
			{description = "45/Use", data = 45},
			{description = "50/Use", data = 50},
		},
		default = 1,
	},
	{
		name = "SPIRALSPEAR_DURABILITY_SPECIAL",
		label = "Special consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1%", data = 1},
			{description = "2%", data = 2},
			{description = "3%", data = 3},
			{description = "4%", data = 4},
			{description = "5%", data = 5},
			{description = "10%", data = 10},
			{description = "15%", data = 15},
			{description = "20%", data = 20},
			{description = "25%", data = 25},
			{description = "30%", data = 30},
			{description = "35%", data = 35},
			{description = "40%", data = 40},
			{description = "45%", data = 45},
			{description = "50%", data = 50},
		},
		default = 5,
	},
	{
		name = "SPIRALSPEAR_COOLDOWN",
		label = "Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Default (12s)", data = 12},
			{description = "+10%", data = 14.4},
			{description = "+25%", data = 15},
			{description = "+50%", data = 18},
			{description = "+75%", data = 21},
			{description = "+100%", data = 24},
		},
		default = 12,
	},
	-- Blacksmith Edge
	{
		name = "Blacksmith Edge options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "BLACKSMITH_EDGE_DISABLE_RECIPE",
		label = "Disable recipe",
		hover = "You can still get this item by using console command.",
		options = {
			{description = "No", data = false},
			{description = "Yes", data = true},
		},
		default = false,
	},
	{
		name = "BLACKSMITH_EDGE_DAMAGE",
		label = "Damages",
		options = {
			{description = "15", data = 15},
			{description = "20", data = 20},
			{description = "25", data = 25},
			{description = "30 (default)", data = 30},
			{description = "35", data = 35},
			{description = "40", data = 40},
			{description = "45", data = 45},
			{description = "50", data = 50},
			{description = "55", data = 55},
			{description = "60", data = 60},
		},
		default = 30,
	},
	{
		name = "BLACKSMITH_EDGE_HELMSPLIT_DAMAGE",
		label = "Jump damages",
		options = {
			{description = "25", data = 25},
			{description = "50", data = 50},
			{description = "100 (default)", data = 100},
			{description = "150", data = 150},
			{description = "200", data = 200},
			{description = "250", data = 250},
			{description = "300", data = 300},
		},
		default = 100,
	},
	{
		name = "BLACKSMITH_EDGE_DURABILITY",
		label = "Durability",
		options = {
			{description = "Infinite", data = 0},
			{description = "100 Uses", data = 100},
			{description = "200 Uses", data = 200},
			{description = "300 Uses", data = 300},
			{description = "400 Uses", data = 400},
			{description = "500 Uses", data = 500},
			{description = "750 Uses", data = 750},
			{description = "1000 Uses", data = 1000},
			{description = "1500 Uses", data = 1500},
			{description = "2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "BLACKSMITH_EDGE_DURABILITY_NORMAL",
		label = "Normal consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1/Use", data = 1},
			{description = "2/Use", data = 2},
			{description = "3/Use", data = 3},
			{description = "4/Use", data = 4},
			{description = "5/Use", data = 5},
			{description = "10/Use", data = 10},
			{description = "15/Use", data = 15},
			{description = "20/Use", data = 20},
			{description = "25/Use", data = 25},
			{description = "30/Use", data = 30},
			{description = "35/Use", data = 35},
			{description = "40/Use", data = 40},
			{description = "45/Use", data = 45},
			{description = "50/Use", data = 50},
		},
		default = 1,
	},
	{
		name = "BLACKSMITH_EDGE_DURABILITY_SPECIAL",
		label = "Damage blocking consumption",
		hover = "Enable durability to use this option",
		options = {
			{description = "1%", data = 1},
			{description = "2%", data = 2},
			{description = "3%", data = 3},
			{description = "4%", data = 4},
			{description = "5%", data = 5},
			{description = "10%", data = 10},
			{description = "15%", data = 15},
			{description = "20%", data = 20},
			{description = "25%", data = 25},
			{description = "30%", data = 30},
			{description = "35%", data = 35},
			{description = "40%", data = 40},
			{description = "45%", data = 45},
			{description = "50%", data = 50},
		},
		default = 5,
	},
	{
		name = "BLACKSMITH_EDGE_COOLDOWN",
		label = "Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Default (12s)", data = 12},
			{description = "+10%", data = 14.4},
			{description = "+25%", data = 15},
			{description = "+50%", data = 18},
			{description = "+75%", data = 21},
			{description = "+100%", data = 24},
		},
		default = 12,
	},
	{
		name = "Global Weapons options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
--------------------------------------
	{
        name = "cursedpig",
        label = "Summon Cursed Pig or not",
		hover = "If enabled, you'll have Cursed Pig when killing normal pigs",
        options = 
        {
			{description = "Off", data = false},
			{description = "On - Give me that challenge", data = true},
        }, 
        default = true,
	},
--------------------------------------
	{
		name = "Global Metallurgy options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_batch",
        label = "Batch smelting",
		hover = "The furnace smelts several units of the same result in one operation, and its slots accept stacks of ore. Off keeps the original one-unit, one-item-per-slot behaviour. The server decides this one; the furnace tells clients what value is in force.",
        options =
        {
			{description = "Off - one unit per operation", data = 0},
			{description = "On - smelt in batches", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_batch_cap",
        label = "Batch size limit",
		hover = "Hard ceiling on units produced by a single operation, whatever the load. Some products cap lower on their own: ore pass-through always gives 1, adamantium gives at most 5.",
        options =
        {
			{description = "4 units", data = 4},
			{description = "10 units", data = 10},
			{description = "20 units", data = 20},
        },
        default = 10,
	},
	{
        name = "mam_batch_time",
        label = "Batch time growth",
		hover = "Extra furnace time per unit beyond the first. 0% means a 10-ingot batch takes the same time as a single ingot, which is a big throughput gain; 25% keeps time roughly in step with the materials used.",
        options =
        {
			{description = "0% - no extra time", data = 0},
			{description = "25% per extra unit", data = 25},
			{description = "50% per extra unit", data = 50},
			{description = "75% per extra unit", data = 75},
        },
        default = 25,
	},
	{
        name = "mam_leftovers",
        label = "Unsmelted leftovers",
		hover = "A batch consumes only the materials it needs. What is left in the slots comes back to you on harvest instead of being destroyed. Off restores the original behaviour, where the whole load was consumed even if part of it was never used.",
        options =
        {
			{description = "Destroy them - original", data = 0},
			{description = "Return them to me", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_forecast",
        label = "Furnace forecast",
		hover = "Shows what the current load will produce, how many and how long, on the furnace button, before you start smelting. When a mixed load could yield more than one alloy, 'Full forecast' lists the possibilities and 'Certain result only' just warns that the outcome is a coin flip.",
        options =
        {
			{description = "Off - original Smelt button", data = 0},
			{description = "Certain result only", data = 1},
			{description = "Full forecast", data = 2},
        },
        default = 2,
	},
	{
		name = "Global Compatibility options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_recipe_overrides",
        label = "Recipe overrides",
		hover = "How far this mod may rewrite VANILLA recipes (science machine costs, gold tools, the craft book's station). Uncompromising Mode Beta and other balance mods write the same recipe fields, and whoever writes last wins in silence. Safe checks each recipe first: if another mod already rebalanced it we keep those numbers and only apply our own station gating. Full always applies our numbers, which is the original 2.9.3 behaviour. Recipes this mod adds on its own are never affected.",
        options =
        {
			{description = "Never - leave vanilla recipes to other mods", data = 0},
			{description = "Safe - only while a recipe is still vanilla", data = 1},
			{description = "Full - original Metals and More behaviour", data = 2},
        },
        default = 1,
	},
	{
		name = "Mining and ore drops",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_extra_drops",
        label = "Extra ore drops",
		hover = "Master switch for every extra material source this mod adds to the world: gold and moon boulders, cave stalagmites, ruins clockworks and chess junk, fire and ice hounds, marble trees and shrubs, and the shark. Turning it off leaves the world's loot exactly as the game and your other mods define it. The mod's own copper and iron rocks are not affected - they are new content, not an override.",
        options =
        {
			{description = "Off - no extra ore anywhere", data = 0},
			{description = "On - use the per-source switches below", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drops_mode",
        label = "Ore drop mode",
		hover = "Additive attaches our materials to each rock or creature when it spawns, on top of whatever loot table is live at that moment. Nothing is overwritten, mod load order stops mattering, and only OUR materials are added - vanilla rocks, flint and gold yields are left alone. Rewrite restores the original 2.9.3 behaviour of replacing whole vanilla loot tables, which also lowers some vanilla yields and can overwrite (or be overwritten by) My Moar Metals and Uncompromising Mode, since both write the same tables. Additive is the compatible default; Rewrite is there if you want the old numbers back.",
        options =
        {
			{description = "Additive - keep other mods' loot (recommended)", data = 1},
			{description = "Rewrite - original 2.9.3 loot tables", data = 2},
        },
        default = 1,
	},
	{
        name = "mam_drops_normalise",
        label = "Cap repeated rolls",
		hover = "The original mod rolls the same material several times on one source - a marble tree rolls gold dust at 1.0, 0.75 and 0.75, so 2.5 pieces on average. On rescales those rolls so a single source averages at most 1 of each material, keeping their relative weights. Off keeps the original numbers exactly. This is the 'no easy farming' knob; it is off by default so the mod's balance is not changed without you asking.",
        options =
        {
			{description = "Off - original 2.9.3 chances", data = 0},
			{description = "On - at most 1 per material per source", data = 1},
        },
        default = 0,
	},
	{
        name = "mam_drop_boulders",
        label = "Boulders: gold and moon rocks",
		hover = "Gold dust from gold boulders (rock2), iron ore from moon rocks and iron ore plus iron dust from moon rock shells. Chances are the ones 2.9.3 declared.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_stalagmites",
        label = "Cave stalagmites and stalactites",
		hover = "Copper ore, copper dust and gold dust from every mining stage of stalagmites and tall stalagmites, plus the occasional gem shard and gold ore. Cave rock is the mod's main copper source, so turning this off makes copper noticeably scarcer.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_chess",
        label = "Ruins: clockworks and chess junk",
		hover = "Knights drop copper ore, rooks and bishops drop copper and iron ingots, nightmare variants drop more, and hammerable chess junk drops gem shards and copper dust. Dangerous ruins creatures giving refined metal is intentional: it is the reward for the risk.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_hounds",
        label = "Fire and ice hounds: gem shards",
		hover = "Uncompromising Mode Beta already reworks fire and ice hound loot to drop red and blue gems. Auto skips our gem shards while UM is enabled, so the same creature is not two gem sources at once; with UM absent, Auto behaves exactly like the original mod. Always adds our shards regardless, which stacks with UM's gems.",
        options =
        {
			{description = "Off", data = 0},
			{description = "Auto - skip when Uncompromising Mode is on", data = 1},
			{description = "Always - even alongside Uncompromising Mode", data = 2},
        },
        default = 1,
	},
	{
        name = "mam_drop_marbletree",
        label = "Marble trees (natural only)",
		hover = "Marble seeds, gold dust and copper ore from the marble trees the world generates. Trees grown from a planted marble seed are deliberately excluded, so ore cannot be farmed by replanting seeds.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_marbleshrub",
        label = "Marble shrubs: iron ore",
		hover = "Iron ore from marble shrubs, one at the normal stage and two at the tall stage, as in 2.9.3. In Additive mode the game's own marble and marble bean roll is kept and our ore is added to it; in Rewrite mode the original fixed loot lists are used.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_shark",
        label = "Shark: sharkscale",
		hover = "Sharkscale from sharks, used by the mod's own equipment. Uncompromising Mode adds its own leather to the same creature through a separate roll, so the two do not conflict.",
        options =
        {
			{description = "Off", data = 0},
			{description = "On", data = 1},
        },
        default = 1,
	},
}
