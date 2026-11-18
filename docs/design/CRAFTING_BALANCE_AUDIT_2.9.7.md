# Crafting and progression balance audit — Metals and More Reforged 2.9.7

Date: 2026-11-12  
Status: source inventory and balance hypotheses; no recipe cost is approved solely by this document.

## Design target

Metals and More should create a perceptible alternative crafting progression built around mining, smelting, alloys, dedicated stations and metal equipment. It must not become a blanket metal tax on every vanilla recipe. Vanilla routes remain viable where they do not conflict with a deliberate MAM replacement.

Every proposed change must be evaluated across:
- **Acquisition:** renewable/finite source, biome, risk, expected quantity and access tier.
- **Processing:** smelter/station, fuel, time, tool, recipe tier and conversion loss.
- **Usage pressure:** how often the material is consumed, progression importance, repairs and competing recipes.

For each recipe, record the vanilla baseline, MAM proposal, delta in raw material value, time/fuel, station tier, and impact on time-to-progression. Test the complete chain, not isolated ingredient counts.

## Current recipe inventory from source

The current values below are read from `initialise/modded_recipes.lua` and `modmain.lua` on the 2.9.7 branch. They are the existing proposal, not newly approved balance decisions.

| Recipe | Vanilla baseline | Current MAM proposal | Audit focus |
|---|---|---|---|
| Science Machine | 1 gold nugget, 4 logs, 4 rocks | 4 iron ore, 4 logs, 4 rocks | Early-game access to iron; ensure no circular dependency and measure time to first science tier |
| Alchemy Engine | 4 boards, 2 cut stone, 2 transistors | 4 boards, 2 iron ingots, 2 transistors | Iron ore demand and smelting time before tier 2 |
| Birdcage | 2 papyrus, 6 gold nuggets, 2 seeds | 2 papyrus, 1 bronze ingot, 2 seeds | Bronze alloy access vs vanilla gold cost |
| Dragonfly Chest | 1 dragon scale, 4 boards, 10 gold nuggets | 1 dragon scale, 4 boards, 2 gold ingots | Gold conversion cost and post-boss utility |
| Compass | 1 gold nugget, 1 flint | 1 iron ore, 1 flint | Early exploration access; raw ore should not become a bottleneck |
| Razor | 2 twigs, 2 flint | 2 twigs, 1 iron ingot | One ingot represents 3 iron-value units in the current smelting table |
| Transistor | 2 gold nuggets, 1 cut stone | 1 copper ingot, 1 cut stone | Copper availability and science progression |
| Lightning Rod | 4 gold nuggets, 1 cut stone | 1 gold ingot, 1 cut stone | Gold ingot currently represents 3 gold-value units |
| Golden Axe/Pickaxe/Shovel/Farm Hoe | 4 twigs, 2 gold nuggets | 4 twigs, 1 gold ingot | The current ingot route raises nominal gold value from 2 to 3 units; assess against durability and tool tier |
| Marble Armor | 6 marble, 2 rope | 6 marble, 2 rope, 1 iron ingot | Rebalanced: preserve vanilla base materials, add one iron ingot and keep the War Workbench gate |
| Portable Cookpot | 2 gold nuggets, 6 charcoal, 6 twigs | 3 iron ore, 6 charcoal, 6 twigs | Compare raw iron acquisition to gold baseline and portable cooking utility |
| Portable Blender | 2 gold nuggets, 2 transistors, 4 twigs | 3 iron ore, 2 transistors, 4 twigs | Avoid charging both the full iron route and the existing transistor gate without clear value |
| Portable Spice Station | 2 gold nuggets, 3 cut stone, 6 twigs | 3 iron ore, 3 cut stone, 6 twigs | Compare material access and the value of portable seasoning |
| Glass Cutter | 1 log, 5 moonglass | 1 board, 1 moonglass ingot | Verify moonglass-ingot conversion yield and lunar progression timing |
| Archive Resonator | 1 moonrock nugget, 1 Thulecite | 2 moonglass ingots, 1 Thulecite | Check lunar material conversion and whether the extra ingot cost is intentional |
| Moon Dial | 1 blue moon eye, 2 moonrock nuggets, 2 ice | 1 blue moon eye, 1 moonglass ingot, 5 marble | Verify material availability in lunar progression; marble should have a clear design reason |
| Moonrock Crater | 3 moonrock nuggets | 1 moonglass ingot, 2 moonrock nuggets, 1 marble | Added processed material and marble; compare against the crater's utility |
| Moonglass Axe | 2 twigs, 3 moonglass | 2 twigs, 1 moonglass ingot, 1 marble | Compare ingot conversion yield and tool durability |
| Metal Smelter | MAM-owned | 4 iron ore, 2 cut stone | Validate earliest access and no softlock |
| War Workbench | MAM-owned | 5 cut stone, 3 iron ingots, 5 charcoal | High-impact progression gate; compare output recipes and station role |
| Marble Chest | MAM-owned | 5 marble, 2 gold ingots, 3 cut stone | Verify real slot count, fire behavior, hammer returns and cost against vanilla chest |
| Cold Safe (fridge) | MAM-owned | 1 gear, 3 iron ingots, 1 blue gem | Verify real slot count, food preservation multiplier and cost against vanilla icebox |

## Confirmed conversion facts from the current smelting code

- One `iron_ingot` requires at least 3 iron-value units and has a 15-second base cook time.
- One `copper_ingot` requires at least 3 copper-value units and has a 15-second base cook time.
- One `gold_ingot` requires `gold>=3` and `metal>=3` simultaneously, with a 15-second base cook time; each `goldnugget` contributes to both tags, so 3 nuggets satisfy both thresholds.
- One `bronze_ingot` requires at least 3 copper-value units plus at least 1 iron-value unit.
- One `moonglass_ingot` requires at least 2 moonglass-value units and moon-tag value.
- These are minimum recipe predicates; the actual load may contain more material, competing candidate recipes, fuel and batch time. Do not equate one ingot with one nugget.

## Required storage audit

The mod already has:
- `marble_chest`: uses the 5×5 chest animation asset and calls `WidgetSetup("marble_chest")`.
- `cold_safe`: uses the 5×5 chest animation asset, has the `fridge` tag and calls `WidgetSetup("cold_safe")`.
- `metal_storage_chest`: legacy prefab kept for save compatibility; no new crafting recipe should be added.

Before changing either existing recipe, resolve the actual registered container widget layouts and food-preservation behavior in the active DST build. The animation asset alone does not prove the slot count. Compare the real capacity and functionality to the vanilla chest/icebox. The marble chest and cold safe must be priced according to their actual delivered utility, not their names or art.

## Priority balance decisions

1. **Early progression:** ensure the smelter can be reached reliably and that the Science Machine / Alchemy Engine changes do not create excessive early iron scarcity.
2. **Core utility recipes:** compass, razor, transistor, lightning rod and golden tools should make metalworking visible without making routine survival utilities disproportionately expensive.
3. **Portable cooking:** review all three portable stations together; avoid stacking metal and transistor costs without a meaningful progression benefit.
4. **Marble armor and storage:** compare material costs to defense, durability, capacity and preservation utility.
5. **Lunar/ruins recipes:** compare ingot conversion cost against actual lunar material yield and unlock timing.
6. **MAM stations/equipment:** validate the combined cost of the smelter, warworkbench, metal tools and weapon/armor recipes as a progression chain.

## Release tests

- Cost-contract tests for every changed recipe, including the baseline and expected MAM signature.
- Conversion tests using the actual smelting planner, not only tag totals.
- Expected ore acquisition and smelting-time estimates for early, mid and late progression.
- Regression tests with vanilla-only, UM Beta, My Moar Metals and supported optional mods.
- Multiplayer and save/load tests for stations and storage.
- In-game checks in the user's test world before calling any balance decision final.

## Explicit exclusions

- Do not add a new metallurgy chest.
- Do not implement global/nearby storage access or automatic withdrawal in this milestone.
- Do not modify Uncompromising Mode, My Moar Metals, Hydrated/Dehydrated, Better Lucy or other mods.
- Do not apply blanket metal substitutions to every vanilla recipe.


---

## 2026-11-18 — inventário integral de receitas e contrato de balanceamento

**Escopo:** fotografia do código da branch empilhada na PR #65. Esta seção registra custos efetivos e cobertura; não aprova mudanças de custo por si só. As receitas permanecem inalteradas nesta etapa.

### 1. Regras de leitura de custo

- As quantidades abaixo são exatamente as chamadas `Ingredient(prefab, amount)` encontradas no código.
- Lingote não equivale a uma pepita. Cobre/ferro exigem 3 unidades de seu valor específico; ouro exige simultaneamente `gold=3` e `metal=3`. Esses requisitos **se sobrepõem**: cada `goldnugget` fornece `gold=1` e `metal=1`, então 3 pepitas satisfazem ambos; não são 6 unidades físicas. O mesmo princípio vale para `copper_ore` e `iron_ore`, que também fornecem `metal=1`.
- Bronze exige 3 cobre + 1 ferro; vidro lunar exige 2 moonglass + pelo menos 1 moon; adamantium exige `steel=3` e um `iron_ingot` nomeado. O custo efetivo deve expandir as entradas físicas e preservar a interseção de tags, sem somar duas vezes o mesmo item.
- A tabela não inventa rendimento de mineração, chance de drop ou tempo de aquisição. Esses valores dependem das fontes/biomas e precisam de dados do jogo/UM antes de alterar custos.



### 1.1. Interseção de tags e divergência lunar que precisam permanecer explícitas

- `smelting.lua` atribui a cada `goldnugget` `gold=1, metal=1`; o predicado de `gold_ingot` pede `gold>=3` e `metal>=3`. O harness confirma que 6 pepitas produzem 2 lingotes. Logo, são 3 pepitas por lingote, não 6.
- `copper_ore` e `iron_ore` também fornecem simultaneamente o metal correspondente e `metal=1`. O requisito de uma tag não deve ser somado como se fosse outro ingrediente.
- `nightmarefuel` fornece `iron=2, steel=1, metal=1`. Adamantium pede `steel>=3` e um `iron_ingot` nomeado: o custo físico atual é 3 nightmarefuel + 1 iron_ingot. Os valores de ferro/metal que vêm junto do nightmarefuel são atributos do mesmo item consumido, não ingredientes adicionais nem retornos separados.
- **Ponto de auditoria lunar:** `PRODUCT_COSTS.moonglass_ingot` debita `moonglass=2, moon=1`, enquanto `smelting.lua` registra o lingote produzido com `moonglass=2, moon=2`. O harness atual confirma que 2 lingotes consomem 4 moonglass + 2 moonrocknugget e deixam 2 moonglass. O valor `moon=2` do produto carrega uma unidade lunar a mais por lingote do que o custo debitado. Isso não gera um item moon separado, mas altera a contabilidade de tags se o lingote voltar à forja; precisa de decisão explícita e teste de não duplicação antes de alterar qualquer valor.
- A diferença lunar é registrada como **divergência de valor a investigar**, não como exploit confirmado nem como correção aprovada. Não alterar a tabela de tags nesta PR.

### 2. Overrides vanilla — assinatura atual MAM

| Receita | Ingredientes atuais | Natureza |
|---|---|---|
| `researchlab` | `iron_ore×4 + log×4 + rocks×4` | Override vanilla protegido por assinatura e recipe guard |
| `researchlab2` | `boards×4 + iron_ingot×2 + transistor×2` | Override vanilla protegido por assinatura e recipe guard |
| `birdcage` | `papyrus×2 + bronze_ingot×1 + seeds×2` | Override vanilla protegido por assinatura e recipe guard |
| `dragonflychest` | `dragon_scales×1 + boards×4 + gold_ingot×2` | Override vanilla protegido por assinatura e recipe guard |
| `compass` | `iron_ore×1 + flint×1` | Override vanilla protegido por assinatura e recipe guard |
| `razor` | `twigs×2 + iron_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `transistor` | `cutstone×1 + copper_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `lightning_rod` | `gold_ingot×1 + cutstone×1` | Override vanilla protegido por assinatura e recipe guard |
| `goldenaxe` | `twigs×4 + gold_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `goldenpickaxe` | `twigs×4 + gold_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `goldenshovel` | `twigs×4 + gold_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `golden_farm_hoe` | `twigs×4 + gold_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `armormarble` | `marble×6 + rope×2 + iron_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `portablecookpot_item` | `iron_ore×3 + charcoal×6 + twigs×6` | Override vanilla protegido por assinatura e recipe guard |
| `portableblender_item` | `iron_ore×3 + transistor×2 + twigs×4` | Override vanilla protegido por assinatura e recipe guard |
| `portablespicer_item` | `iron_ore×3 + cutstone×3 + twigs×6` | Override vanilla protegido por assinatura e recipe guard |
| `glasscutter` | `boards×1 + moonglass_ingot×1` | Override vanilla protegido por assinatura e recipe guard |
| `archive_resonator_item` | `thulecite×1 + moonglass_ingot×2` | Override vanilla protegido por assinatura e recipe guard |
| `moondial` | `bluemooneye×1 + moonglass_ingot×1 + marble×5` | Override vanilla protegido por assinatura e recipe guard |
| `moonrockcrater` | `moonglass_ingot×1 + moonrocknugget×2 + marble×1` | Override vanilla protegido por assinatura e recipe guard |
| `moonglassaxe` | `moonglass_ingot×1 + twigs×2 + marble×1` | Override vanilla protegido por assinatura e recipe guard |

### 3. Receitas próprias MAM — assinatura atual

| Receita | Ingredientes atuais | Natureza |
|---|---|---|
| `metal_smelter` | `iron_ore×4 + cutstone×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `marbleseed` | `iron_ore×1 + marble×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `mam_stone_chisel` | `twigs×2 + flint×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `warworkbench` | `cutstone×5 + iron_ingot×3 + charcoal×5` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `metallurgy_reference_book` | `papyrus×2 + charcoal×2 + iron_ingot×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `armor_sanity` | `adamantium_ingot×2 + papyrus×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `nightsword` | `adamantium_ingot×2 + livinglog×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `marble_chest` | `marble×5 + gold_ingot×2 + cutstone×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `cold_safe` | `gears×1 + iron_ingot×3 + bluegem×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `jagged_armor` | `houndstooth×4 + gold_ingot×3 + armormarble×1 + iron_ingot×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `tfwp_luxury_nox_helm_hat` | `footballhat×1 + gold_ingot×3 + walrus_tusk×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `halberd` | `log×2 + iron_ingot×3 + rope×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `scepter` | `gold_ingot×3 + purplegem×1 + livinglog×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `forkstick` | `gold_ingot×3 + sharkscale×3 + gnarwail_horn×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `shears` | `log×1 + flint×2 + iron_ingot×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `donharpoon` | `marble×2 + flint×3 + iron_ingot×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `dst_willowdoll` | `beefalowool×4 + sewing_kit×1 + charcoal×10` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `forginghammer` | `hammer×1 + lightninggoathorn×1 + gold_ingot×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `pithpike` | `lightninggoathorn×2 + gold_ingot×3 + houndstooth×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `spiralspear` | `marble×3 + pithpike×1 + townportaltalisman×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `blacksmith_edge` | `marble×5 + driftwood_log×2 + gold_ingot×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `forginghammerold` | `twigs×4 + marble×2 + gold_ingot×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `pithpikeold` | `marble×2 + gold_ingot×1 + houndstooth×3` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `blacksmith_edgeold` | `marble×4 + driftwood_log×2 + gold_ingot×1` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |
| `craftbook` | `papyrus×2 + charcoal×2` | Receita própria/estação; conferir tier e utilidade antes de reequilibrar |

### 4. Receitas movidas ao Craftbook — custos preservados

Estas receitas são migradas para a estação Craftbook pelo adaptador `modded_craftbook.lua`. A lista abaixo registra os ingredientes da lista MAM atual; a integração só deve adaptar a receita quando a assinatura viva corresponder ao baseline suportado, preservando a receita de terceiros quando divergir.

| Receita | Ingredientes atuais | Natureza |
|---|---|---|
| `seedpouch` | `slurtle_shellpieces×2 + cutgrass×4 + seeds×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `icepack` | `bearger_fur×1 + gears×1 + transistor×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `piggyback` | `pigskin×4 + silk×6 + rope×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `sewing_kit` | `log×1 + silk×8 + houndstooth×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `flowerhat` | `petals×12` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `purpleamulet` | `goldnugget×6 + nightmarefuel×4 + purplegem×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `amulet` | `goldnugget×3 + nightmarefuel×2 + redgem×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `blueamulet` | `goldnugget×3 + bluegem×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `umbrella` | `twigs×6 + pigskin×1 + silk×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `molehat` | `mole×2 + transistor×2 + wormlight×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `minerhat` | `strawhat×1 + bronze_ingot×1 + fireflies×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `backpack` | `cutgrass×4 + twigs×4` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `armorslurper` | `slurper_pelt×6 + rope×2 + nightmarefuel×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `icehat` | `transistor×2 + rope×4 + ice×10` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `beefalohat` | `beefalowool×8 + horn×2 + winterhat×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `earmuffshat` | `rabbit×2 + twigs×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `winterhat` | `beefalowool×4 + silk×4 + earmuffshat×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `beehat` | `silk×8 + rope×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `trunkvest_summer` | `trunk_summer×1 + silk×8` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `bushhat` | `strawhat×1 + rope×1 + dug_berrybush×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `catcoonhat` | `coontail×3 + silk×4` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `sweatervest` | `houndstooth×8 + silk×6` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `eyebrellahat` | `deerclops_eyeball×1 + twigs×15 + boneshard×4` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `watermelonhat` | `watermelon×1 + twigs×3` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `featherhat` | `feather_crow×3 + feather_robin×2 + tentaclespots×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `hawaiianshirt` | `papyrus×3 + silk×3 + cactus_flower×5` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `beargervest` | `bearger_fur×1 + sweatervest×1 + rope×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `cane` | `gold_ingot×2 + walrus_tusk×1 + twigs×4` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `tophat` | `silk×6` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `strawhat` | `cutgrass×12` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `reflectivevest` | `rope×1 + feather_robin×3 + pigskin×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `rainhat` | `mole×2 + strawhat×1 + boneshard×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `raincoat` | `tentaclespots×2 + rope×2 + boneshard×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `trunkvest_winter` | `trunk_winter×1 + silk×8 + beefalowool×2` | Migração de estação; ingredientes mantidos pela lista MAM atual |
| `bernie_inactive` | `beardhair×3 + beefalowool×6 + sewing_kit×1` | Migração de estação; ingredientes mantidos pela lista MAM atual |

### 5. Tábuas e pedra — requisitos nativos de ferramenta

A implementação de `mam/tool_crafting.lua` acrescenta um requisito de ferramenta sem alterar a economia nativa da receita. A fonte instalada do DST consultada em 2026-11-17 registrou:

| Receita | Ingredientes nativos | Regra MAM |
|---|---|---|
| `boards` | `log×4` | Machado funcional; não consumido |
| `woodie_boards` | `log×3 + lucy×0` | Machado funcional; preserva skill e encaminhamento vanilla |
| `boards_bunch` | `log×20` | Machado funcional; lote de 5 |
| `cutstone` | `rocks×3` | Cinzel reutilizável; não consumido |
| `cutstone_bunch` | `rocks×15` | Cinzel reutilizável; lote de 5 |

- Machado: tags `tool` + `CHOP_tool` e, no servidor, componente `tool` real com `CanDoAction(CHOP)`, efetividade positiva e usos restantes válidos.
- Cinzel: prefab e tag MAM dedicados; sem durabilidade, sem stack consumível e sem ação de combate.
- Cliente e servidor verificam inventário/equipamento; servidor revalida posse e capacidade no instante da fabricação. Freebuild é exceção consistente nos dois lados.
- O escopo de busca é inventário, equipamento, cursor e overflow equipado gravável; armazenamento aberto/próximo/nested não é procurado.
- A Mesa de Serragem continua fora do código: não foi encontrado/validado um prefab/API do alvo atual que justifique integração. Não reativar receita vanilla por hipótese.

### 6. Leitura quantitativa preliminar e decisões bloqueadas

| Área | Evidência atual | Risco / decisão necessária |
|---|---|---|
| Primeira ciência e fundição | Science Machine: 4 iron_ore; Metal Smelter: 4 iron_ore + 2 cutstone, em Science One | Duas despesas de 4 iron_ore antes/na entrada da metalurgia. Medir aquisição inicial de ferro e confirmar que não há softlock; não reduzir custo sem curva de mineração |
| Alchemy Engine | 2 iron_ingot = mínimo 6 iron-value, além de 4 boards e 2 transistors | Medir tempo de obtenção/fundição e concorrência com War Workbench |
| Birdcage | 1 bronze_ingot = mínimo 3 copper + 1 iron | Verificar disponibilidade de cobre/ferro antes de Birdcage; comparar com custo vanilla de 6 goldnuggets |
| Dragonfly Chest | 2 gold_ingot = 6 goldnuggets (cada uma fornece gold + metal), mais boss scale e boards | Custo composto; conferir se requisito pós-boss e capacidade justificam 2 barras |
| Compass / Razor | Compass usa 1 iron_ore; Razor usa 1 iron_ingot = mínimo 3 iron-value | Compass troca gold por iron; Razor troca flint por três unidades de ferro e precisa de comparação funcional |
| Transistor / Lightning Rod | 1 copper_ingot = 3 copper ore; 1 gold_ingot = 3 gold nuggets (as mesmas 3 unidades satisfazem gold e metal) | Confirmar oferta de cobre/ouro; não contar lingote como 1 nugget nem dobrar tag sobreposta |
| Ferramentas douradas | 1 gold_ingot cada = 3 goldnuggets (gold=3 e metal=3 pelas mesmas unidades), contra 2 goldnuggets vanilla | Aumenta o custo físico de ouro em 50%; revisar durabilidade/velocidade e concorrência de lingotes |
| Marble Armor | 6 marble + 2 rope + 1 iron_ingot | Mantém o custo vanilla de marble/rope e acrescenta 3 iron-value; estação metalúrgica permanece como gate |
| Cozinha portátil | Três itens exigem 3 iron_ore cada; blender também mantém 2 transistors | Avaliar o pacote junto: não cobrar ferro + transistores sem benefício proporcional |
| Lunar | Moonglass ingot requer 2 moonglass + moon; vidro/arquivo/moondial/crater/axe adicionam marble/boards | Expandir conversão, confirmar disponibilidade de moonrock/moonglass e progressão lunar antes de alterar |
| Estações MAM | Smelter 4 iron ore + 2 cutstone; War Workbench 3 iron_ingot + 5 cutstone + 5 charcoal; book 1 iron_ingot | Verificar soma acumulada e gargalo entre primeira forja, bancada e equipamento |
| Armazenamento MAM | Marble Chest 2 gold_ingot + 5 marble + 3 cutstone; Cold Safe 3 iron_ingot + gear + bluegem | Não balancear sem confirmar slots reais, preservação, resistência ao fogo, martelamento e retornos |
| Equipamentos próprios | Armaduras/armas usam 2–3 ingots por família, além de itens de boss/raridade | Comparar dano, defesa, durabilidade, reparo e estação; separar receitas legadas opcionais das atuais |

**Sem mudanças de custo nesta etapa.** As fontes de aquisição ainda não estão quantificadas com amostras controladas e o teste in-game está pendente. A próxima alteração deve escolher um grupo fechado, calcular o custo expandido, definir baseline/objetivo e adicionar regressão antes de editar receitas.



### 6.1. Orçamento cumulativo até a primeira War Workbench

A partir das assinaturas atuais, o caminho mínimo de estações fica:

| Etapa | Custo metalúrgico acumulado |
|---|---|
| Science Machine | 4 iron-value (4 iron_ore na rota direta), 4 logs, 4 rocks |
| Metal Smelter | +4 iron-value, +2 cutstone |
| Alchemy Engine | +6 iron-value (2 iron ingots), +6 copper-value (2 copper ingots para 2 transistors), +2 cutstone, +4 boards |
| War Workbench | +9 iron-value (3 iron ingots), +5 cutstone, +5 charcoal |

**Total direto até a primeira War Workbench:** 23 iron-value, 6 copper-value, 9 cutstone e 5 charcoal, além de 4 logs + 4 rocks para a Science Machine e 4 boards para a Alchemy Engine. Quatro boards equivalem a 16 logs na receita comum; Woodie preserva sua rota própria de 3 logs por board, portanto o custo de madeira pode variar por personagem sem alterar o gate de ferramenta.

Esse total é um **orçamento de valor de ingrediente**, não uma previsão de 23 iron ore físicos: iron dust contribui 0,5 iron por unidade, nightmarefuel contribui iron=2 e outras fontes podem fornecer os mesmos valores. A conversão de valor para tempo de jogo depende da frequência de cada fonte, bioma, risco, combustível e lotes. O número revela a pressão acumulada da progressão, mas não prova softlock nem justifica reduzir custo sem amostragem controlada.

O livro opcional acrescenta 1 iron ingot (3 iron-value), 2 papyrus e 2 charcoal depois de Alchemy One; não está incluído no total obrigatório da bancada.



### 6.2. Fontes de aquisição configuradas — rendimento esperado por evento

Esta tabela soma os rolls independentes de `AddChanceLoot` na configuração padrão: `mam_extra_drops=1`, modo aditivo, normalização desligada e multiplicadores de chance em 100%. É **expectativa por evento de mineração/colheita/morte**, não quantidade garantida em cada evento nem rendimento por dia. Os drops vanilla continuam separados.

| Fonte / evento | Drops MAM esperados por evento | Valor metalúrgico esperado | Estágio / ressalva |
|---|---|---|---|
| `ironrock` (novo boulder) | 2,50 `iron_ore` | 2,50 iron-value | Rota de superfície; worldgen distribui peso 0,75 em sete famílias de salas Rocky/BGDirt/SpiderVillage |
| `rock2` | 1,75 `gold_dust` | 0,875 gold-value | Superfície; 0,75 + 1,00 rolls |
| `rock_moon` | 1,00 `iron_ore` | 1,00 iron-value | Lunar; dois rolls de 0,50 |
| `rock_moon_shell` | 0,50 `iron_ore` + 0,75 `iron_dust` | 0,875 iron-value | Lunar; poeira vale 0,5 iron por unidade |
| `stalagmite` / full | 1,50 `copper_ore` + 2,50 `copper_dust` + 0,75 `gold_dust` | 2,75 copper-value + 0,375 gold-value | Caverna; gem shards adicionais não entram no valor metálico |
| `stalagmite_med` | 1,60 `copper_ore` + 1,75 `copper_dust` + 0,50 `gold_dust` | 2,475 copper-value + 0,25 gold-value | Caverna |
| `stalagmite_low` | 0,50 `copper_ore` + 1,75 `copper_dust` + 0,25 `gold_dust` | 1,375 copper-value + 0,125 gold-value | Caverna |
| `stalagmite_tall` / full | 1,00 `copper_ore` + 2,00 `copper_dust` + 1,35 `gold_dust` | 2,00 copper-value + 0,675 gold-value | Caverna |
| `stalagmite_tall_med` | 1,35 `copper_ore` + 2,00 `copper_dust` + 1,00 `gold_dust` | 2,35 copper-value + 0,50 gold-value | Caverna |
| `stalagmite_tall_low` | 0,75 `copper_ore` + 1,30 `copper_dust` + 1,00 `gold_dust` + 0,05 `gold_ore` legado | 1,40 copper-value + 0,50 gold-value (mais alias legado) | Caverna; confirmar o caminho de conversão de `gold_ore` |
| Clockwork Knight | 1,50 `copper_ore` | 1,50 copper-value | Ruínas; perigo maior que rochas |
| Clockwork Rook | 1,50 `copper_ingot` + 1,00 `iron_ingot` | 4,50 copper-value + 3,00 iron-value | Ruínas; fonte de lingotes de estágio avançado |
| Clockwork Bishop | 0,75 `copper_ingot` + 1,00 `iron_ingot` | 2,25 copper-value + 3,00 iron-value | Ruínas; gem shards adicionais |
| Nightmare Bishop | 0,50 `copper_ingot` + 1,00 `iron_ingot` | 1,50 copper-value + 3,00 iron-value | Ruínas; purple shards adicionais |
| Árvore de mármore natural | 1,00 `copper_ore` + 2,50 `gold_dust` + 0,25 `goldnugget` | 1,00 copper-value + 1,50 gold-value | Somente `marbletree` natural; árvores plantadas `marbletree_1..4` são excluídas |
| Arbusto de mármore, estágio 2/3 | 1 / 2 `iron_ore` adicionados ao loot do estágio | 1 / 2 iron-value | Quantidade ajustável; preservar o loot vanilla e verificar frequência/regeneração in-game |
| Rocky selvagem | 0,20 `copper_dust` + 0,05 `iron_dust` | 0,10 copper-value + 0,025 iron-value | Fonte secundária; seguidores do jogador são excluídos |
| Slurtle / Snurtle | 0,08 / 0,12 `iron_dust` | 0,04 / 0,06 iron-value | Fonte secundária, poeira apenas |
| Rubble / estátuas antigas | 0,15 `copper_dust` + 0,05 `iron_dust` | 0,075 copper-value + 0,025 iron-value | Fonte secundária; mineração preserva drops vanilla |

**Interpretação para a primeira bancada:** 23 iron-value equivalem matematicamente a cerca de 9,2 eventos de `ironrock` se todo o ferro viesse dessa fonte (2,5 por evento). Isso não estima quantos `ironrock` existem em um mundo nem quanto tempo o jogador leva para encontrá-los; o peso de distribuição 0,75 não é uma contagem de spawn. As amostras de mundo e a rota real de mineração ainda precisam ser medidas.

**Limites da tabela:**
- Roll repetido do mesmo item é independente no modo aditivo; com normalização desligada, as probabilidades somam valor esperado (por exemplo, marbletree tem 2,50 gold_dust esperado).
- O modo Rewrite é opt-in e pode substituir loot compartilhado; não é o baseline padrão.
- A fonte de gem shards de Fire/Ice Hounds cede ao UM quando a configuração está em Auto; não contar os shards do MAM como rendimento adicional em UM Beta.
- `spikyrock` tem tabela de loot no prefab, mas não foi encontrado peso de distribuição para ele em `modworldgenmain.lua`; não incluí-lo como rota garantida de mundo até confirmar outra origem de spawn.
- As chances/quantidades registradas são configuração de código; a frequência de eventos, disponibilidade de biomas e resultado real por mundo não foram amostrados.


### 6.3. Rebalanceamento aplicado — Marble Suit / `armormarble`

**Decisão:** o custo MAM foi ajustado de `marble×12 + rope×4 + iron_ingot×1` para `marble×6 + rope×2 + iron_ingot×1`.

**Evidência:** a receita vanilla de DST é 6 marble + 2 rope na Alchemy Engine. A armadura mantém os atributos vanilla documentados para DST: 735 de condição, 95% de absorção e penalidade de movimento de 30%. A versão anterior do MAM duplicava marble e rope e ainda acrescentava um iron ingot, sem evidência de aumento dos atributos defensivos. Isso criava um triplo custo de entrada (matéria-prima base duplicada + metalurgia) para o mesmo equipamento. Referência de jogo: [Marble Suit — DST Wiki](https://dontstarve.wiki.gg/wiki/Marble_Suit/DST).

O novo custo preserva os materiais vanilla e adiciona 1 iron ingot (3 iron-value), enquanto a receita continua submetida ao filtro da bancada metalúrgica/War Workbench. Assim, a metalurgia é exigida sem cobrar duas vezes a progressão de marble/rope. A mudança não altera atributos, durabilidade, velocidade ou comportamento da armadura.

**Efeito indireto:** `jagged_armor` consome uma `armormarble`; seu custo composto cai em 6 marble e 2 rope, mas permanecem os 3 gold ingots, 3 iron ingots e 4 houndstooth próprios da receita. A armadura Jagged não foi alterada: seus atributos (1500 de condição, 85% de absorção e +10% de velocidade) indicam um equipamento distinto e exigem uma auditoria separada antes de mexer no preço.

**Limite:** é um ajuste de custo fundamentado em baseline e atributos de código/documentação; não é uma declaração de balanceamento final. Frequência real de marble, impacto no tempo até a primeira armadura e comportamento multiplayer continuam sem amostragem no motor DST. A documentação oficial da Klei confirma que mods podem ajustar tuning de itens e regras de mundo, mas não substitui validação no jogo: [Klei — Modding Don't Starve and Don't Starve Together](https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together).


### 6.4. Auditoria de dano — `forkstick`

**Correção aplicada:** o prefab definia `weapon:SetDamage(math.random(12,99))` durante a criação do item. Isso não era uma faixa aleatória por golpe: cada instância recebia um dano-base diferente, com intervalo de 87 pontos, sem opção de configuração, sem indicação no tooltip e sem regra de progressão. Duas cópias do mesmo item podiam ter valores muito diferentes.

O dano agora usa `TUNING.SPEAR_DAMAGE`, o baseline de lança do DST (34 de dano). A referência de jogo documenta a lança com 34 de dano e 150 usos: [Spear/DST](https://dontstarve.wiki.gg/wiki/Spear/DST). A escolha mantém o forkstick na escala de uma arma vanilla conhecida, em vez de deixar uma ferramenta de travessia aquática variar aleatoriamente entre dano de ferramenta e dano muito acima de armas avançadas.

A alteração **não** modifica receita (`gold_ingot×3 + sharkscale×3 + gnarwail_horn×1`), combustível, duração de travessia, controle de afogamento, umidade, usos ou efeitos visuais. O item ainda exige comparação de desempenho e segurança em runtime/multiplayer. A comunidade possui mods de combate que oferecem dano aleatório de forma deliberada, mas com min/max e opções explícitas; exemplo: [Papapav's Armory](https://steamcommunity.com/workshop/filedetails/?id=3370627907). Esse padrão explícito não existia no forkstick.

### 6.5. Comparação de equipamentos — prioridades da próxima rodada

A comparação usa somente valores DST, não variantes single-player. As referências vanilla mostram que dano, usos, efeitos especiais, mobilidade e custo de oportunidade precisam ser avaliados em conjunto:

| Item | Código MAM / custo atual | Comparação DST | Leitura de balanceamento |
|---|---|---|---|
| Jagged Armor | 1500 condição, 85% absorção, +10% velocidade; `houndstooth×4 + gold_ingot×3 + armormarble×1 + iron_ingot×3` | Marble Suit: 735 condição, 95%, -30% velocidade | Armadura de mobilidade e maior durabilidade, menor absorção; custo alto pode ser justificável, mas validar dano efetivo absorvido e duração antes de mexer |
| Halberd | 51 dano, 150 usos, chop eficiência 7, -15% velocidade, -0,25 sanity; `iron_ingot×3 + log×2 + rope×1` | Spear: 34 dano/150 usos; Dark Sword: 68/100 | Mult ferramenta com penalidades e fome ao cortar; 51 fica entre lança e espada sombria, manter em observação |
| Don Harpoon | 80 dano, 150 usos, alcance 12–14, projétil velocidade 30, -20% velocidade; `iron_ingot×2 + marble×2 + flint×3` | Dark Sword e Glass Cutter: 68 dano; Dark Sword 100 usos, Glass Cutter 75 (até 150 contra sombras) | **Maior candidato a revisão:** supera dano das armas vanilla de alto tier e adiciona alcance/projétil e 150 usos; penalidade de movimento e custo de metal contam a favor, então não nerfar sem verificar comportamento de arremesso/recuperação e dano real |
| Scepter | 32 dano, alcance 1,6, bônus de velocidade de cane, combustível; `gold_ingot×3 + purplegem×1 + livinglog×2` | Spear 34 dano; Walking Cane é mobilidade, não arma de dano alto | Dano modesto com mobilidade e fuel; avaliar utilidade/fuel, não só DPS |
| Forkstick | 34 dano (corrigido), 50 usos, fuel; atravessa água ao suspender afogamento enquanto equipado; `gold_ingot×3 + sharkscale×3 + gnarwail_horn×1` | Spear 34 dano/150 usos | Dano agora está no baseline da lança; o valor do item está na travessia aquática e no combustível, não em dano aleatório |
| Shears | 17 dano, 500 usos, `areapicker` raio 4; `iron_ingot×2 + log×1 + flint×2` | Ferramentas vanilla comuns causam 17 dano; durabilidade e área são a vantagem | Ferramenta de coleta em área, não arma; validar quantos recursos colhe por uso e possíveis interações com ActionQueue/mods de colheita |
| Night Armor / Dark Sword | Cada receita usa 2 adamantium ingots; Night Armor também 3 papyrus, Dark Sword 1 livinglog | Night Armor vanilla: 525 condição, 95%, -10 sanity/min e -10% do dano recebido; Dark Sword: 68 dano, 100 usos, -20 sanity/min | O custo MAM expande cada 2 adamantium para 6 nightmarefuel + 2 iron ingots. É uma cobrança metalúrgica adicional relevante, mas os itens já são de tier alto; medir concorrência com outros usos de adamantium antes de alterar |

Referências: [Spear/DST](https://dontstarve.wiki.gg/wiki/Spear/DST), [Dark Sword/DST](https://dontstarve.wiki.gg/wiki/Dark_Sword/DST), [Night Armor/DST](https://dontstarve.wiki.gg/wiki/Night_Armor/DST), [Glass Cutter](https://dontstarve.wiki.gg/wiki/Glass_Cutter), [Elding Spear](https://dontstarve.wiki.gg/wiki/Elding_Spear), [Marble Suit/DST](https://dontstarve.wiki.gg/wiki/Marble_Suit/DST), [Metals and More! Reworked — Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2792388184).

**Decisão desta rodada:** ajustar Marble Suit, estabilizar Forkstick e alinhar Don Harpoon ao baseline de 68 dano/100 usos da Dark Sword. O alcance 12–14 e a natureza de projétil permanecem como vantagem, compensados pela penalidade de movimento de 20% e pelo custo de 2 iron ingots + 2 marble + 3 flint. A validação de arremesso, recuperação e consumo de usos continua pendente.

### 6.6. Verificação dos caminhos de aquisição e migração

**Marble shrubs:** `initialise/modded_drops.lua` lê `growable.stage` e acrescenta 1 `iron_ore` no estágio 2 e 2 no estágio 3. No modo aditivo padrão, encadeia o `lootsetupfn` anterior e preserva o loot vanilla/outros mods; conta os `iron_ore` já existentes antes de inserir, evitando duplicação. O hook não altera o componente `growable`, estágios, timers ou regrowth. Portanto, a quantidade de minério por colheita está definida, mas a frequência de regrowth continua sendo a do jogo e não foi amostrada.

**Legacy `gold_ore`:** não é um prefab ausente. `modmain.lua` registra `goldore`; `scripts/prefabs/goldore.lua` retorna `Prefab("gold_ore")` e substitui a entidade legada por `goldnugget` preservando stack size e, quando possível, slot/container. A conversão ocorre após 0,1 s. Assim, o roll de 0.05 `gold_ore` da tabela de stalagmite tall low produz o item de ouro atual, não um drop nulo. `modworldgenmain.lua` também define `countprefabs.gold_ore = math.random(5)` para a sala `Graveyard`; isso é um valor por definição de sala, não uma contagem total de mundo, porque o número de instâncias dessa sala não foi medido.

**`spikyrock`:** o prefab e a tabela de loot existem em `newrocks.lua`, mas a distribuição direta em `modworldgenmain.lua` só registra `ironrock` e `iron_ore` nas salas rocky e `gold_ore` no Graveyard. Não há `spikyrock` em `AddRoomPreInit`/distribuição do MAM. Tratar como prefab disponível para spawn externo/console ou outra integração, não como fonte garantida na economia atual.

**Resultado:** o caminho do arbusto é aditivo e preserva o regrowth vanilla; o alias de ouro está confirmado e converte; o spikyrock continua fora do orçamento de aquisição até aparecer uma rota de spawn real. Nenhum rendimento por dia/mundo foi inferido a partir de pesos de densidade.

### 7. Cobertura de inventário

- Overrides vanilla registrados: 21.
- Receitas próprias encontradas em `modmain.lua`, `modded_recipes.lua` e `modded_craftbook.lua`: 25.
- Receitas migradas ao Craftbook: 35.
- A cobertura é validada por `tests/test_mam_crafting_balance_contract.py`, que compara as assinaturas do código com esta documentação. Receita nova sem registro ou custo alterado sem atualização deliberada da matriz falha na CI.
