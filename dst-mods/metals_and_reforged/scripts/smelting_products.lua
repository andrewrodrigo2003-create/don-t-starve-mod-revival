local foods =

{
	copper_ore =
	{
		test = function(cooker, names, tags) return tags.copper and tags.copper >= 1 end,
		priority = 1,
		cooktime = 10,
		ore = true
	},

	iron_ore =
	{
		test = function(cooker, names, tags) return tags.iron and tags.iron >= 1 end,
		priority = 1,
		cooktime = 10,
		ore = true
	},

	goldnugget =
	{
		test = function(cooker, names, tags) return tags.gold and tags.gold >= 1 end,
		priority = 1,
		cooktime = 10,
		oldprefab = true
	},

	copper_ingot =
	{
		test = function(cooker, names, tags) return tags.copper and tags.copper >= 3 end,
		priority = 10,
		cooktime = 15,
	},
	
	iron_ingot =
	{
		test = function(cooker, names, tags) return tags.iron and tags.iron >= 3 end,
		priority = 10,
		cooktime = 15,
	},
	
	bronze_ingot =
	{
		test = function(cooker, names, tags) return tags.iron and tags.iron >= 1 and tags.copper and tags.copper >= 3 end,
		priority = 20,
		cooktime = 15,
	},

	moonglass_ingot =
	{
		test = function(cooker, names, tags) return tags.moon and tags.moonglass and tags.moonglass >= 2 end,
		priority = 20,
		cooktime = 15,
	},

--[[
	adamantium_ingot =
	{
		test = function(cooker, names, tags) return names.moonglass_ingot and tags.steel and names.iron_ingot and names.gold_ingot end,
		priority = 100,
		cooktime = 25,
	},
]]
	adamantium_ingot =
	{
		test = function(cooker, names, tags) return tags.steel and tags.steel >= 3 and names.iron_ingot end,
		priority = 100,	--100
		cooktime = 30,	--25
	},

	gold_ingot =
	{	
		test = function(cooker, names, tags) return tags.gold and tags.gold >= 3 and tags.metal and tags.metal >= 3 end,
		priority = 30,
		cooktime = 15,
	},	
	
--	rose_gold_ingot =
--	{	
--		test = function(cooker, names, tags) return tags.gold and tags.gold >= 3 and tags.purple end,
--		priority = 3,
--		cooktime = smelting_base_time * 2,
--	},	
	
--	platinum_ingot =
--	{	
--		test = function(cooker, names, tags) return names.rose_gold_ingot and tags.green and tags.yellow and tags.orange end,
--		priority = 4,
--		cooktime = smelting_base_time * 3,
--	},	

	junk_dust =
	{	
		test = function(cooker, names, tags) return tags.metal end,
		priority = -2,
		cooktime = 5,
	},
	
	nitre =
	{	
		test = function(cooker, names, tags) return ((tags.mineral) or (tags.gem and tags.gem < 1)) end,
		priority = -3,
		cooktime = 5,
		oldprefab = true
	},
	
	purplegem =
	{	
		test = function(cooker, names, tags) return tags.blue and tags.blue >= 2 and tags.red and tags.red >= 2 end,
		priority = 20,
		cooktime = 20,
		oldprefab = true
	},
	
	redgem =
	{	
		test = function(cooker, names, tags) return tags.red and tags.red >= 4 end,
		priority = 10,
		cooktime = 20,
		oldprefab = true
	},
	
	bluegem =
	{	
		test = function(cooker, names, tags) return tags.blue and tags.blue >= 4 end,
		priority = 10,
		cooktime = 20,
		oldprefab = true
	},
	
	greengem =
	{	
		test = function(cooker, names, tags) return tags.yellow and tags.yellow >= 1.5 and tags.blue and tags.blue >= 1.5 and not tags.red and not tags.metal end,
		priority = 20,
		cooktime = 20,
		oldprefab = true
	},
	
	yellowgem =
	{	
		test = function(cooker, names, tags) return tags.yellow and tags.yellow >= 3 and not tags.metal and not tags.carbon end,
		priority = 20,
		cooktime = 20,
		oldprefab = true
	},
	
	orangegem =
	{	
		test = function(cooker, names, tags) return tags.yellow and tags.yellow >= 1.5 and tags.red and tags.red >= 1.5 and not tags.blue and not tags.metal end,
		priority = 20,
		cooktime = 20,
		oldprefab = true
	},
	
	opalgem =
	{	
		test = function(cooker, names, tags) return tags.gem and tags.gem >= 1 end,
		priority = 0,
		cooktime = 20,
		oldprefab = true
	},
	
}

-- Custo por UNIDADE produzida. Cada numero aqui e o proprio limiar da funcao
-- `test` acima, transcrito para que o motor de lote possa dividir a carga.
-- Nada foi reequilibrado: se a test pede tags.copper >= 3, o custo e copper = 3.
-- max_batch teto por operacao; 1 nos produtos "ore" que sao devolucao de
-- mineral (fundo de balde), para o lote nao multiplicar o no-op.
local PRODUCT_COSTS =
{
	copper_ore        = { tags = { copper = 1 },                     max_batch = 1 },
	iron_ore          = { tags = { iron = 1 },                       max_batch = 1 },
	goldnugget        = { tags = { gold = 1 },                        max_batch = 1 },
	junk_dust         = { tags = { metal = 1 },                      max_batch = 1 },
	-- A receita original tambem aceita fragmentos de gema quando o total de gem < 1.
	-- Nesse caminho alternativo, o lote consome toda a carga elegivel; sem isso,
	-- nenhum custo mineral era debitado e a forja podia gerar nitre repetidamente.
	nitre             = { tags = { mineral = 1 }, consume_all_if_unmatched = true },

	copper_ingot      = { tags = { copper = 3 } },
	iron_ingot        = { tags = { iron = 3 } },
	gold_ingot        = { tags = { gold = 3, metal = 3 } },
	bronze_ingot      = { tags = { iron = 1, copper = 3 } },
	-- A receita tambem exige a presenca de moon; consome 1 unidade desse requisito
	-- por barra para nao reutilizar o mesmo moonrocknugget em fundicoes sucessivas.
	moonglass_ingot   = { tags = { moonglass = 2, moon = 1 } },
	adamantium_ingot  = { tags = { steel = 3 }, names = { iron_ingot = 1 }, max_batch = 5 },

	redgem            = { tags = { red = 4 } },
	bluegem           = { tags = { blue = 4 } },
	purplegem         = { tags = { blue = 2, red = 2 } },
	greengem          = { tags = { yellow = 1.5, blue = 1.5 } },
	yellowgem         = { tags = { yellow = 3 } },
	orangegem         = { tags = { yellow = 1.5, red = 1.5 } },
	opalgem           = { tags = { gem = 1 } },
}

for k,v in pairs(foods) do
	v.name = k
	v.weight = v.weight or 1
	v.priority = v.priority or 0

	local cost = PRODUCT_COSTS[k]
	if cost ~= nil then
		v.cost = { tags = cost.tags, names = cost.names }
		v.consume_all_if_unmatched = cost.consume_all_if_unmatched == true
		v.max_batch = cost.max_batch
	end
end

return foods