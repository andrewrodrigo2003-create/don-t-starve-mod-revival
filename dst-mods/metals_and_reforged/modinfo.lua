name = "Metals and More Reforged"
description = "Fabrique equipamentos metálicos, recupere materiais e consulte o guia de metalurgia na Bancada de Guerra. / Forge metal equipment, recover materials and study the metallurgy guide at your War Bench."
author = "NevilleDST"
version = "2.9.6"
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
        name = "mam_language",
        label = "Language / Idioma",
        hover = "Escolha Português (Brasil) ou Inglês para Metals and More Reforged. / Choose Brazilian Portuguese or English for Metals and More Reforged.",
        options = {
            { description = "Português (Brasil)", data = "ptbr" },
            { description = "English", data = "en" },
        },
        default = "ptbr",
    },
	{
        name = "craftingbook",
        label = "Livro de criação / Crafting book",
		hover = "Ativado: exige o livro para fabricar roupas, mochilas e algumas outras receitas. / If enabled, you'll need the book to craft clothing items (backpacks, etc.) and some other recipes.",
        options = 
        {
			{description = "Desligado / Off", data = false},
			{description = "Ligado / On", data = true},
        }, 
        default = false,
	},
	{
        name = "cookbookcook",
        label = "Cozinhar com o livro de receitas / Cookbook cooking",
		hover = "Ativado: é necessário equipar o Livro de Receitas para cozinhar. / If enabled, you'll need the Cookbook equipped to be able to cook.",
        options = 
        {
			{description = "Desligado / Off", data = false},
			{description = "Ligado / On", data = true},
        }, 
        default = false,
	},
	{
        name = "Disable Normal Map",
        label = "Sobrevivência do mapa / Map survival",
		hover = "Ativado: equipe a bússola para acessar o mapa. / If enabled, you need to equip the compass to access the map.",
        options = 
        {
			{description = "Desligado / Off", data = false},
			{description = "Ligado / On", data = true},
        }, 
        default = false,
	},
	{
        name = "disablemapchanges",
        label = "Usa mod de minimapa? / Using Minimap mod?",
		hover = "Ao escolher Desligado, o uso de um mod de minimapa fica seguro. / If you choose OFF, it's safe to use a minimap mod.",
        options = 
        {
			{description = "Desligado / Off", data = false},
			{description = "Ligado / On", data = true},
        }, 
        default = false,
	},
----------------------------------------------
    {
        name = "legacy_forge_weapon_abilities",
        label = "Habilidades antigas das armas da Forja / Legacy Forge weapon abilities",
        hover = "Ativa as habilidades antigas das armas do evento The Forge e hooks globais de combate/StateGraph. Desativado por padrão por compatibilidade; não afeta a metalurgia. / Enables the old Forge Event weapon abilities and global combat/StateGraph hooks. Disabled by default for compatibility; does not affect metallurgy.",
        options = {
            { description = "Desligado - modo de compatibilidade / Off - Compatibility mode", data = false },
            { description = "Ligado - ativar habilidades antigas / On - Enable legacy abilities", data = true },
        },
        default = false,
    },
    {
        name = "Opções gerais de armas / Global Weapons options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "forge_weapons",
        label = "Armas antigas ou novas da Forja / Old vs New Forge weapons",
		hover = "Seleciona a variante da receita somente quando as habilidades antigas da Forja estão ativadas. / Selects the recipe variant only when Legacy Forge weapon abilities are enabled.",
        options = 
        {
			{description = "Desligado - usar armas antigas / Off - Give me old weapons.", data = false},
			{description = "Ligado - usar essas habilidades / On - Give me those abilities.", data = true},
        }, 
        default = false,
	},
------------------------------------------------
	{
		name = "Opções gerais da Forja / Global Forge options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "PREVENT_COMPAGNION_ATTACK",
		label = "Impedir ataques a companheiros / Disable companion attacks",
		hover = "Impede que jogadores ataquem companheiros. / Prevents players from attacking companions.",
		options = {
			{description = "Não / No", data = false},
			{description = "Sim / Yes", data = true},
		},
		default = false,
	},
	-- Forging hammer
	{
		name = "Opções do Martelo de Forja / Forging Hammer options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "FORGING_HAMMER_DISABLE_RECIPE",
		label = "Desativar receita / Disable recipe",
		hover = "O item ainda pode ser obtido pelo comando do console. / You can still get this item by using a console command.",
		options = {
			{description = "Não / No", data = false},
			{description = "Sim / Yes", data = true},
		},
		default = false,
	},
	{
		name = "FORGINGHAMMER_DAMAGE",
		label = "Dano / Damage",
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
		label = "Dano especial / Special damage",
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
		label = "Durabilidade / Durability",
		options = {
			{description = "Infinita / Infinite", data = 0},
			{description = "100 usos / 100 Uses", data = 100},
			{description = "200 usos / 200 Uses", data = 200},
			{description = "300 usos / 300 Uses", data = 300},
			{description = "400 usos / 400 Uses", data = 400},
			{description = "500 usos / 500 Uses", data = 500},
			{description = "750 usos / 750 Uses", data = 750},
			{description = "1000 usos / 1000 Uses", data = 1000},
			{description = "1500 usos / 1500 Uses", data = 1500},
			{description = "2000 usos / 2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "FORGING_HAMMER_DURABILITY_NORMAL",
		label = "Consumo normal / Normal consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Consumo especial / Special consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Tempo de recarga / Cooldown",
		options = {
			{description = "-75%", data = 3},
			{description = "-50%", data = 9},
			{description = "-25%", data = 13.5},
			{description = "-10%", data = 16.2},
			{description = "Padrão (18s) / Default (18s)", data = 18},
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
		name = "Opções da Lança de Pith / Pith Pike options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "PITHPIKE_DISABLE_RECIPE",
		label = "Desativar receita / Disable recipe",
		hover = "O item ainda pode ser obtido pelo comando do console. / You can still get this item by using a console command.",
		options = {
			{description = "Não / No", data = false},
			{description = "Sim / Yes", data = true},
		},
		default = false,
	},
	{
		name = "PITHPIKE_DAMAGE",
		label = "Dano / Damage",
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
		label = "Dano especial / Special damage",
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
		label = "Durabilidade / Durability",
		options = {
			{description = "Infinita / Infinite", data = 0},
			{description = "100 usos / 100 Uses", data = 100},
			{description = "200 usos / 200 Uses", data = 200},
			{description = "300 usos / 300 Uses", data = 300},
			{description = "400 usos / 400 Uses", data = 400},
			{description = "500 usos / 500 Uses", data = 500},
			{description = "750 usos / 750 Uses", data = 750},
			{description = "1000 usos / 1000 Uses", data = 1000},
			{description = "1500 usos / 1500 Uses", data = 1500},
			{description = "2000 usos / 2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "PITHPIKE_DURABILITY_NORMAL",
		label = "Consumo normal / Normal consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Consumo especial / Special consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Tempo de recarga / Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Padrão (12s) / Default (12s)", data = 12},
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
		name = "Opções da Lança Espiral / Spiral Spear options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "SPIRALSPEAR_DISABLE_RECIPE",
		label = "Desativar receita / Disable recipe",
		hover = "O item ainda pode ser obtido pelo comando do console. / You can still get this item by using a console command.",
		options = {
			{description = "Não / No", data = false},
			{description = "Sim / Yes", data = true},
		},
		default = false,
	},
	{
		name = "SPIRALSPEAR_DAMAGE",
		label = "Dano / Damage",
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
		label = "Dano especial / Special damage",
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
		label = "Durabilidade / Durability",
		options = {
			{description = "Infinita / Infinite", data = 0},
			{description = "100 usos / 100 Uses", data = 100},
			{description = "200 usos / 200 Uses", data = 200},
			{description = "300 usos / 300 Uses", data = 300},
			{description = "400 usos / 400 Uses", data = 400},
			{description = "500 usos / 500 Uses", data = 500},
			{description = "750 usos / 750 Uses", data = 750},
			{description = "1000 usos / 1000 Uses", data = 1000},
			{description = "1500 usos / 1500 Uses", data = 1500},
			{description = "2000 usos / 2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "SPIRALSPEAR_DURABILITY_NORMAL",
		label = "Consumo normal / Normal consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Consumo especial / Special consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Tempo de recarga / Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Padrão (12s) / Default (12s)", data = 12},
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
		name = "Opções do Fio do Ferreiro / Blacksmith Edge options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
		name = "BLACKSMITH_EDGE_DISABLE_RECIPE",
		label = "Desativar receita / Disable recipe",
		hover = "O item ainda pode ser obtido pelo comando do console. / You can still get this item by using a console command.",
		options = {
			{description = "Não / No", data = false},
			{description = "Sim / Yes", data = true},
		},
		default = false,
	},
	{
		name = "BLACKSMITH_EDGE_DAMAGE",
		label = "Dano / Damage",
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
		label = "Dano do salto / Jump damage",
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
		label = "Durabilidade / Durability",
		options = {
			{description = "Infinita / Infinite", data = 0},
			{description = "100 usos / 100 Uses", data = 100},
			{description = "200 usos / 200 Uses", data = 200},
			{description = "300 usos / 300 Uses", data = 300},
			{description = "400 usos / 400 Uses", data = 400},
			{description = "500 usos / 500 Uses", data = 500},
			{description = "750 usos / 750 Uses", data = 750},
			{description = "1000 usos / 1000 Uses", data = 1000},
			{description = "1500 usos / 1500 Uses", data = 1500},
			{description = "2000 usos / 2000 Uses", data = 2000},
		},
		default = 0,
	},
	{
		name = "BLACKSMITH_EDGE_DURABILITY_NORMAL",
		label = "Consumo normal / Normal consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Consumo ao bloquear dano / Damage-blocking consumption",
		hover = "Ative a durabilidade para usar esta opção. / Enable durability to use this option.",
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
		label = "Tempo de recarga / Cooldown",
		options = {
			{description = "-90%", data = 1},
			{description = "-75%", data = 3},
			{description = "-50%", data = 6},
			{description = "-25%", data = 9},
			{description = "-10%", data = 9.6},
			{description = "Padrão (12s) / Default (12s)", data = 12},
			{description = "+10%", data = 14.4},
			{description = "+25%", data = 15},
			{description = "+50%", data = 18},
			{description = "+75%", data = 21},
			{description = "+100%", data = 24},
		},
		default = 12,
	},
	{
		name = "Opções gerais de armas / Global Weapons options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
--------------------------------------
	{
        name = "cursedpig",
        label = "Invocar o Porco Amaldiçoado? / Summon Cursed Pig?",
		hover = "Ativado: um Porco Amaldiçoado aparece ao matar porcos comuns. / If enabled, a Cursed Pig appears when killing normal pigs.",
        options = 
        {
			{description = "Desligado / Off", data = false},
			{description = "Ligado - ativar esse desafio / On - Give me that challenge", data = true},
        }, 
        default = true,
	},
--------------------------------------
	{
		name = "Opções gerais de metalurgia / Global Metallurgy options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_batch",
        label = "Fundição em lotes / Batch smelting",
		hover = "A forja processa várias unidades do mesmo resultado por operação e aceita pilhas de minério. Desligado mantém uma unidade por operação e um item por espaço. O servidor define a opção e a forja informa os clientes. / The furnace smelts several units of the same result in one operation, and its slots accept stacks of ore. Off keeps the original one-unit, one-item-per-slot behaviour. The server decides this one; the furnace tells clients what value is in force.",
        options =
        {
			{description = "Desligado - uma unidade por operação / Off - one unit per operation", data = 0},
			{description = "Ligado - fundir em lotes / On - smelt in batches", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_batch_cap",
        label = "Limite do tamanho do lote / Batch size limit",
		hover = "Limite máximo de unidades produzidas por operação. Alguns produtos têm limites próprios: minério repassado sempre gera 1; adamantium gera no máximo 5. / Hard ceiling on units produced by a single operation, whatever the load. Some products cap lower on their own: ore pass-through always gives 1, adamantium gives at most 5.",
        options =
        {
			{description = "4 unidades / 4 units", data = 4},
			{description = "10 unidades / 10 units", data = 10},
			{description = "20 unidades / 20 units", data = 20},
        },
        default = 10,
	},
	{
        name = "mam_batch_time",
        label = "Aumento de tempo por lote / Batch time growth",
		hover = "Tempo adicional de forja por unidade após a primeira. 0% faz um lote de 10 lingotes levar o mesmo tempo de um único lingote; 25% mantém o tempo proporcional aos materiais usados. / Extra furnace time per unit beyond the first. 0% means a 10-ingot batch takes the same time as a single ingot; 25% keeps time roughly in step with the materials used.",
        options =
        {
			{description = "0% - sem tempo extra / 0% - no extra time", data = 0},
			{description = "25% por unidade extra / 25% per extra unit", data = 25},
			{description = "50% por unidade extra / 50% per extra unit", data = 50},
			{description = "75% por unidade extra / 75% per extra unit", data = 75},
        },
        default = 25,
	},
	{
        name = "mam_leftovers",
        label = "Materiais não fundidos / Unsmelted leftovers",
		hover = "O lote consome somente os materiais necessários. O restante volta ao jogador na coleta em vez de ser destruído. Desligado restaura o comportamento original, que consumia toda a carga. / A batch consumes only the materials it needs. What is left in the slots comes back to you on harvest instead of being destroyed. Off restores the original behaviour, where the whole load was consumed even if part of it was never used.",
        options =
        {
			{description = "Destruir - original / Destroy them - original", data = 0},
			{description = "Devolver ao jogador / Return them to me", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_forecast",
        label = "Previsão da forja / Furnace forecast",
		hover = "Mostra no botão da forja o resultado previsto, a quantidade e o tempo antes de iniciar. Se uma carga mista puder gerar mais de uma liga, Previsão completa lista as possibilidades; Resultado certo apenas avisa sobre a incerteza. / Shows what the current load will produce, how many and how long, on the furnace button, before you start smelting. When a mixed load could yield more than one alloy, 'Full forecast' lists the possibilities and 'Certain result only' just warns that the outcome is a coin flip.",
        options =
        {
			{description = "Desligado - botão Fundir original / Off - original Smelt button", data = 0},
			{description = "Somente resultado certo / Certain result only", data = 1},
			{description = "Previsão completa / Full forecast", data = 2},
        },
        default = 2,
	},
	{
		name = "Opções gerais de compatibilidade / Global Compatibility options",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_recipe_overrides",
        label = "Substituição de receitas / Recipe overrides",
		hover = "Controla as alterações de ingredientes/custos em receitas VANILLA do MAM. Seguro preserva ingredientes alterados por outros mods; Completo força os valores originais 2.9.3; Desligado desativa essas alterações. A integração de receitas de terceiros é controlada separadamente. Nenhuma dessas opções controla o machado, cinzel ou Mesa de Serragem do MAM. Receitas próprias não são afetadas. / Controls this mod's VANILLA ingredient/cost overrides. Safe keeps another mod's changed ingredients; Full forces our original 2.9.3 ingredient values; Off disables those cost overrides. The separate third-party recipe integration switch controls whether supported recipes changed by other mods may be moved to our progression. Neither option controls MAM-owned axe, chisel or Sawing Table mechanics. Recipes added by this mod are unaffected.",
        options =
        {
			{description = "Nunca - deixar receitas vanilla para outros mods / Never - leave vanilla recipes to other mods", data = 0},
			{description = "Seguro - somente enquanto a receita for vanilla / Safe - only while a recipe is still vanilla", data = 1},
			{description = "Completo - comportamento original do Metals and More / Full - original Metals and More behaviour", data = 2},
        },
        default = 1,
	},
	{
		name = "Mineração e drops de minério / Mining and ore drops",
		options = {
			{description = "", data = 0}
		},
		default = 0,
	},
	{
        name = "mam_extra_drops",
        label = "Drops extras de minério / Extra ore drops",
		hover = "Chave geral para todas as fontes extras de materiais do MAM: rochas de ouro e lunares, formações de cavernas, mecanismos das Ruínas, cães elementais, árvores e arbustos de mármore e tubarão. Desligar preserva os drops do jogo e de outros mods. As rochas próprias de cobre e ferro do MAM não são afetadas. / Master switch for every extra material source this mod adds to the world: gold and moon boulders, cave stalagmites, ruins clockworks and chess junk, fire and ice hounds, marble trees and shrubs, and the shark.",
        options =
        {
			{description = "Desligado - sem minério extra / Off - no extra ore anywhere", data = 0},
			{description = "Ligado - usar controles por fonte abaixo / On - use the per-source switches below", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drops_mode",
        label = "Modo de drops de minério / Ore drop mode",
		hover = "Aditivo adiciona os materiais do MAM ao loot de cada rocha/criatura sem substituir tabelas existentes; ordem de carregamento deixa de importar e os drops vanilla são preservados. Substituir restaura o comportamento 2.9.3, que troca tabelas inteiras e pode conflitar com My Moar Metals e Uncompromising Mode. Aditivo é o padrão compatível. / Additive attaches our materials to each rock or creature without replacing live loot tables; load order stops mattering and vanilla yields remain unchanged. Rewrite restores the 2.9.3 behaviour of replacing whole vanilla loot tables and can conflict with My Moar Metals and Uncompromising Mode. Additive is the compatible default.",
        options =
        {
			{description = "Aditivo - preservar drops de outros mods (recomendado) / Additive - keep other mods' loot (recommended)", data = 1},
			{description = "Substituir - tabelas de loot originais 2.9.3 / Rewrite - original 2.9.3 loot tables", data = 2},
        },
        default = 1,
	},
	{
        name = "mam_drops_normalise",
        label = "Limitar rolagens repetidas / Cap repeated rolls",
		hover = "O mod original pode rolar o mesmo material várias vezes na mesma fonte; uma árvore de mármore, por exemplo, tem média de 2,5 poeiras de ouro. Ligado normaliza as rolagens para no máximo 1 unidade média de cada material por fonte, preservando pesos relativos. Desligado mantém os números originais. / The original mod can roll the same material several times from one source; a marble tree averages 2.5 gold dust. On rescales rolls to at most 1 average unit of each material per source while preserving relative weights. Off keeps original numbers.",
        options =
        {
			{description = "Desligado - chances originais 2.9.3 / Off - original 2.9.3 chances", data = 0},
			{description = "Ligado - no máximo 1 por material por fonte / On - at most 1 per material per source", data = 1},
        },
        default = 0,
	},
	{
        name = "mam_drop_boulders",
        label = "Rochas: ouro e rochas lunares / Boulders: gold and moon rocks",
		hover = "Poeira de ouro em rochas douradas (rock2), minério de ferro em rochas lunares e minério de ferro + poeira de ferro nas conchas lunares. As chances seguem os valores declarados na versão 2.9.3. / Gold dust from gold boulders (rock2), iron ore from moon rocks and iron ore plus iron dust from moon rock shells. Chances match 2.9.3.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_stalagmites",
        label = "Estalagmites e estalactites / Cave stalagmites and stalactites",
		hover = "Minério e poeira de cobre, além de poeira de ouro, em cada estágio de mineração de estalagmites e estalagmites altas; ocasionalmente, fragmentos de gema e minério de ouro. Rochas de cavernas são a principal fonte de cobre do mod, então desligar esta opção torna o cobre mais raro. / Copper ore, copper dust and gold dust from every mining stage of stalagmites and tall stalagmites, plus occasional gem shards and gold ore. Cave rock is the mod's main copper source, so turning this off makes copper scarcer.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_chess",
        label = "Ruínas: mecanismos e sucata de xadrez / Ruins: clockworks and chess junk",
		hover = "Cavaleiros soltam minério de cobre; torres e bispos soltam lingotes de cobre e ferro; variantes de pesadelo soltam mais; sucata de xadrez quebrável solta fragmentos de gema e poeira de cobre. Metais refinados de criaturas perigosas das Ruínas são uma recompensa intencional pelo risco. / Knights drop copper ore, rooks and bishops drop copper and iron ingots, nightmare variants drop more, and hammerable chess junk drops gem shards and copper dust. Refined metal from dangerous Ruins creatures is intentional risk reward.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_hounds",
        label = "Cães de fogo e gelo: fragmentos de gema / Fire and ice hounds: gem shards",
		hover = "O Uncompromising Mode Beta já altera o loot dos cães de fogo e gelo para soltar gemas vermelhas e azuis. Automático ignora os fragmentos do MAM quando UM está ativo, evitando duas fontes de gema na mesma criatura; sem UM, funciona como o mod original. Sempre adiciona nossos fragmentos, acumulando com as gemas de UM. / Uncompromising Mode Beta already makes fire and ice hounds drop red and blue gems. Auto skips MAM shards while UM is enabled; without UM it behaves like the original mod. Always adds our shards alongside UM.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Automático - ignorar quando Uncompromising Mode estiver ativo / Auto - skip when Uncompromising Mode is on", data = 1},
			{description = "Sempre - mesmo com Uncompromising Mode / Always - even alongside Uncompromising Mode", data = 2},
        },
        default = 1,
	},
	{
        name = "mam_drop_marbletree",
        label = "Árvores de mármore (somente naturais) / Marble trees (natural only)",
		hover = "Sementes de mármore, poeira de ouro e minério de cobre das árvores geradas naturalmente pelo mundo. Árvores cultivadas de sementes plantadas são excluídas para impedir farm de minério por replantio. / Marble seeds, gold dust and copper ore from naturally generated marble trees. Trees grown from planted seeds are excluded to prevent ore farming by replanting.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_marbleshrub",
        label = "Arbustos de mármore: minério de ferro / Marble shrubs: iron ore",
		hover = "Minério de ferro de arbustos de mármore: uma unidade no estágio normal e duas no alto, como na versão 2.9.3. No modo Aditivo, os drops vanilla de mármore e feijão de mármore são preservados e o minério é acrescentado; em Substituir, usam-se as listas fixas antigas. / Iron ore from marble shrubs: one at normal stage and two at tall stage, as in 2.9.3. Additive keeps vanilla marble and marble-bean rolls; Rewrite uses the original fixed loot lists.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
	{
        name = "mam_drop_shark",
        label = "Tubarão: escama de tubarão / Shark: sharkscale",
		hover = "Escamas de tubarão usadas nos equipamentos do MAM. O Uncompromising Mode adiciona seu couro por uma rolagem separada, então os dois drops não entram em conflito. / Sharkscale is used by MAM equipment. Uncompromising Mode adds its leather through a separate roll, so the drops do not conflict.",
        options =
        {
			{description = "Desligado / Off", data = 0},
			{description = "Ligado / On", data = 1},
        },
        default = 1,
	},
    {
        name = "mam_drop_rocky",
        label = "Rocky: poeira mineral / Rock Lobsters: mineral dust",
        hover = "Rocky selvagens podem soltar pequenas quantidades de poeira de cobre e, raramente, ferro. Rockies seguindo um jogador nao geram esses drops. / Wild Rockys may drop small amounts of copper dust and rarely iron dust. Player-following Rockies are excluded.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_rubble",
        label = "Escombros de cavernas / Cave rubble",
        hover = "Minerar escombros naturais de cavernas pode revelar poeira de cobre e, raramente, ferro. Os drops originais de pedra sao preservados. / Mining natural cave rubble may reveal copper dust and rarely iron dust. Original rock drops are preserved.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_ancient_statues",
        label = "Estatuas antigas das Ruinas / Ancient Ruins statues",
        hover = "Minerar estatuas antigas pode revelar poeira metalica em pequenas quantidades. Gemas e Thulecite originais nao sao alteradas. / Mining ancient statues may reveal small amounts of metal dust. Original gems and Thulecite are unchanged.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_rocky_chance", label = "Chance: Rocky / Rocky chance",
        hover = "Multiplicador apenas dos drops MAM de Rockys selvagens. / Scales only MAM drops from wild Rockys.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_rubble_chance", label = "Chance: escombros / Rubble chance",
        hover = "Multiplicador apenas dos drops MAM de escombros naturais de cavernas. / Scales only MAM drops from natural cave rubble.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_ancient_statues_chance", label = "Chance: estatuas antigas / Ancient statues chance",
        hover = "Multiplicador apenas dos drops MAM de estatuas das Ruinas. / Scales only MAM drops from ancient Ruins statues.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_knight",
        label = "Cavaleiro mecânico / Clockwork Knight",
        hover = "Minério de cobre. Também respeita o controle geral de criaturas das Ruínas. / Copper ore. Also obeys the Ruins family master switch.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_knight_chance",
        label = "Chance: Cavaleiro mecânico / Clockwork Knight",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_rook",
        label = "Torre mecânica / Clockwork Rook",
        hover = "Lingotes de cobre e ferro. / Copper and iron ingots.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_rook_chance",
        label = "Chance: Torre mecânica / Clockwork Rook",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_bishop",
        label = "Bispo mecânico / Clockwork Bishop",
        hover = "Fragmentos de gemas e lingotes raros. / Gem shards and rare ingots.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_bishop_chance",
        label = "Chance: Bispo mecânico / Clockwork Bishop",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_chessjunk",
        label = "Sucata de xadrez / Chess junk",
        hover = "Poeira de cobre e fragmentos de gemas. / Copper dust and gem shards.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_chessjunk_chance",
        label = "Chance: Sucata de xadrez / Chess junk",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_firehound",
        label = "Cão de fogo / Fire Hound",
        hover = "Fragmentos de rubi; a regra Auto do Uncompromising Mode continua valendo. / Red gem shards; Uncompromising Mode Auto behavior is preserved.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_firehound_chance",
        label = "Chance: Cão de fogo / Fire Hound",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_icehound",
        label = "Cão de gelo / Ice Hound",
        hover = "Fragmentos de safira; a regra Auto do Uncompromising Mode continua valendo. / Blue gem shards; Uncompromising Mode Auto behavior is preserved.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_icehound_chance",
        label = "Chance: Cão de gelo / Ice Hound",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_slurtle",
        label = "Lesma-de-casco / Slurtle",
        hover = "Poeira de ferro rara, como resíduo mineral do casco. / Rare iron dust from mineral traces in its shell.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_slurtle_chance",
        label = "Chance: Lesma-de-casco / Chance: Slurtle",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_snurtle",
        label = "Caracol-de-casco / Snurtle",
        hover = "Poeira de ferro rara, um pouco mais provável que em Slurtles. / Rare iron dust, slightly more likely than from Slurtles.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_drop_snurtle_chance",
        label = "Chance: Caracol-de-casco / Chance: Snurtle",
        hover = "Ajusta somente os drops do Metals and More desta criatura. / Scales only Metals and More drops from this creature.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
	{
        name = "mam_robot_smelting",
        label = "Automação da forja com robô coletor / Collector robot forge automation",
        hover = "Com um W.O.B.O.T. ou W.I.N.bot ativo por perto, a forja pode retirar somente ingredientes registrados de baús e containers fixos compatíveis próximos. Mochilas, armazenamento portátil e inventários de jogadores não são vasculhados. Desativado por padrão. / With an active W.O.B.O.T. or W.I.N.bot nearby, the smelter can pull only registered ingredients from compatible fixed chests/containers. Backpacks, portable storage and player inventories are never scanned. Disabled by default.",
        options =
        {
            {description = "Desligado / Off", data = 0},
            {description = "Ligado / On", data = 1},
        },
        default = 0,
	},


    {
        name = "mam_axe_crafting",
        label = "Tábuas com machado / Axe woodworking",
        hover = "Exige machado funcional carregado, equipado ou na mochila. Preserva custo, estação e requisito de habilidade de cada receita, incluindo a receita especial de Lucy do Woodie. Não consome nem desgasta o machado ao fabricar. / Preserves each recipe cost, station and skill requirement, including Woodie's special Lucy recipe. Crafting does not consume or wear the axe.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_chisel_crafting",
        label = "Pedra com cinzel / Chisel stoneworking",
        hover = "Exige Cinzel de Entalhe em Pedra reutilizável carregado ou na mochila. Mantém custo e estação da pedra trabalhada. Cinzel: 2 gravetos e 2 pedras lascadas, sem estação, sem desgaste. / Requires a reusable Stone-Carving Chisel carried or in a backpack. Keeps cut-stone cost and station. Chisel: 2 twigs and 2 flint, no station or durability. Independent of integrations.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Ligado / On", data = 1}},
        default = 1,
    },
    {
        name = "mam_third_party_recipe_integration",
        label = "Receitas de outros mods / Other-mod recipes",
        hover = "Ativado: adapta receitas compatíveis preservando ingredientes e metadados. Desativado: deixa receitas de terceiros intactas. Não desativa machado, cinzel ou Mesa de Serragem próprios do MAM. / On adapts supported recipes while preserving ingredients and metadata. Off leaves third-party recipes untouched. Does not disable MAM-owned axe, chisel or Sawing Table mechanics.",
        options = {{description = "Desligado - não alterar receitas de outros mods / Off - leave other mods' recipes alone", data = 0}, {description = "Ligado - adaptar receitas compatíveis com segurança / On - adapt supported recipes safely", data = 1}},
        default = 1,
    },
    {
        name = "mam_allow_third_party_drop_overrides",
        label = "Substituir drops de outros mods / Replace other-mod loot",
        hover = "Aplica-se somente ao modo Rewrite antigo. Ativado permite substituir tabelas de loot compartilhadas. Desativado força drops aditivos e preserva as tabelas existentes. / Only applies to legacy Rewrite mode. On permits replacing shared loot tables. Off forces additive drops and preserves live tables.",
        options = {{description = "Desligado - preservar drops de outros mods (recomendado) / Off - preserve other mods' loot (recommended)", data = 0}, {description = "Ligado - permitir substituição de tabelas antigas / On - allow legacy table replacement", data = 1}},
        default = 0,
    },
    {
        name = "mam_drop_boulders_chance", label = "Chance de drops em rochas / Boulder drop chance",
        hover = "Ajusta somente os materiais do Metals and More obtidos de rochas de ouro e lunares. / Scales only Metals and More materials from gold and moon boulders.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_stalagmites_chance", label = "Chance em estalagmites / Cave formation drop chance",
        hover = "Ajusta somente os materiais do Metals and More obtidos de estalagmites e estalactites. / Scales only Metals and More materials from cave stalagmites and stalactites.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_chess_chance", label = "Chance em criaturas das ruínas / Ruins creature drop chance",
        hover = "Ajusta somente os materiais do Metals and More obtidos de mecanismos e peças de xadrez. / Scales only Metals and More materials from clockworks and chess junk.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_hounds_chance", label = "Chance de fragmentos em cães elementais / Hound gem-shard chance",
        hover = "Ajusta somente os fragmentos de gemas do Metals and More. A opção Auto/Sempre continua controlando a interação com Uncompromising Mode. / Scales only Metals and More gem-shard rolls. The separate Auto/Always option still controls Uncompromising Mode interaction.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_marbletree_chance", label = "Chance em árvores de mármore / Marble-tree drop chance",
        hover = "Ajusta somente os materiais do Metals and More obtidos de árvores de mármore naturais. / Scales only Metals and More material rolls from naturally generated marble trees.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_shark_chance", label = "Chance de escama de tubarão / Sharkscale drop chance",
        hover = "Ajusta somente as chances de escama de tubarão adicionadas pelo Metals and More. / Scales only the sharkscale rolls added by Metals and More.",
        options = {{description = "25%", data = 25}, {description = "50%", data = 50}, {description = "75%", data = 75}, {description = "100% (padrão) / 100% (default)", data = 100}, {description = "125%", data = 125}, {description = "150%", data = 150}},
        default = 100,
    },
    {
        name = "mam_drop_marbleshrub_quantity", label = "Minério dos arbustos de mármore / Marble-shrub iron ore",
        hover = "Controla somente a quantidade de minério de ferro do Metals and More. Os demais drops do arbusto e de outros mods não mudam. / Controls only Metals and More iron ore quantity. Other shrub loot and other mods' drops are unchanged.",
        options = {{description = "Desligado / Off", data = 0}, {description = "Original", data = 100}, {description = "Double", data = 200}, {description = "Triple", data = 300}},
        default = 100,
    },

}