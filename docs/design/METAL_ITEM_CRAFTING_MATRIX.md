# Matriz inicial de itens metálicos e bancadas

Status: inventário estático inicial; nenhuma receita ou custo foi alterado por este documento.
Data: 2026-11-08.

## Objetivo do requisito

O usuário quer que os itens metálicos elegíveis do jogo possam ser fabricados individualmente na bancada do Metals and More, com custos próprios e balanceados. A estação de referência atual é `warworkbench` (nome exibido: Armory), com árvore `ALCHEMY_ONE`. O `craftbook` é um prototyper separado (`CRAFTSBOOK_ONE`) e não deve ser confundido com a bancada.

Antes de mover receitas, confirmar em jogo a exclusividade real do filtro `CRAFTING_STATION` e a disponibilidade na bancada. Não assumir que `TECH.ALCHEMY_ONE` por si só prova exclusividade.

## 1. Materiais metalúrgicos — preservar o processamento

| Grupo | Prefabs encontrados | Estado atual | Diretriz inicial |
|---|---|---|---|
| Minérios | `copper_ore`, `iron_ore`, `goldnugget`/`gold_ore` | mineração, drops e receitas de fundição | manter mineração/fundição como rota principal; não criar atalhos de bancada sem decisão explícita |
| Poeiras | `copper_dust`, `iron_dust`, `gold_dust`, `junk_dust` | ingredientes/saídas da metalurgia | manter como materiais de processo |
| Lingotes e ligas | `copper_ingot`, `iron_ingot`, `bronze_ingot`, `gold_ingot`, `moonglass_ingot`, `adamantium_ingot` | saídas da forja e insumos de equipamento | preservar custos, prioridades e progressão da forja |
| Ingredientes especiais | `nightmarefuel` (tag steel), `moonglass`, `moonrocknugget` | ingredientes de aço/adamantium e vidro lunar | não classificar como produtos metálicos sem revisar a semântica de cada receita |

Os fragmentos e gemas (`redgem_shard`, `bluegem_shard`, `yellowgem_shard`, `greengem_shard`, `orangegem_shard`, `purplegem_shard`, gemas completas e `opalgem`) participam do sistema de fundição, mas não são metais; manter separados na matriz.

## 2. Equipamentos e estruturas do mod já fabricáveis com metal

| Prefab | Custo atual encontrado | Estação/tech configurada | Ação |
|---|---|---|---|
| `warworkbench` | 5 cutstone, 3 iron_ingot, 5 charcoal | Science Two / estrutura | manter como estação principal |
| `metal_storage_chest` | 3 iron_ingot, 2 cutstone, 1 gears | `ALCHEMY_ONE` + `CRAFTING_STATION` | integrado; validar em jogo |
| `armor_sanity` | 2 adamantium_ingot, 3 papyrus | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar exclusividade |
| `nightsword` | 2 adamantium_ingot, 1 livinglog | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar exclusividade |
| `jagged_armor` | 4 houndstooth, 3 gold_ingot, 1 armormarble, 3 iron_ingot | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; comparar progressão |
| `tfwp_luxury_nox_helm_hat` | 1 footballhat, 3 gold_ingot, 1 walrus_tusk | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `halberd` | 2 log, 3 iron_ingot, 1 rope | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `scepter` | 3 gold_ingot, 1 purplegem, 2 livinglog | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `forkstick` | 3 gold_ingot, 3 sharkscale, 1 gnarwail_horn | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `shears` | 1 log, 2 flint, 2 iron_ingot | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `donharpoon` | 2 marble, 3 flint, 2 iron_ingot | `ALCHEMY_ONE` + `CRAFTING_STATION` | já metalúrgico; validar balanceamento |
| `forginghammer` | 1 hammer, 1 lightninggoathorn, 3 gold_ingot | `ALCHEMY_ONE` + `CRAFTING_STATION` quando `forge_weapons` ligado | preservar opção e validar |
| `pithpike` | 2 lightninggoathorn, 3 gold_ingot, 3 houndstooth | `ALCHEMY_ONE` + `CRAFTING_STATION` quando `forge_weapons` ligado | preservar opção e validar |
| `spiralspear` | 3 marble, 1 pithpike, 2 townportaltalisman | `ALCHEMY_ONE` + `CRAFTING_STATION` quando `forge_weapons` ligado | preservar opção e validar |
| `blacksmith_edge` | 5 marble, 2 driftwood_log, 3 gold_ingot | `ALCHEMY_ONE` + `CRAFTING_STATION` quando `forge_weapons` ligado | preservar opção e validar |

As variantes antigas `forginghammerold`, `pithpikeold` e `blacksmith_edgeold` também têm receitas próprias quando `forge_weapons` está desligado. Não remover nem duplicar sem uma decisão de migração.

## 3. Receitas vanilla atualmente reescritas com materiais metalúrgicos

| Prefab | Custo atual no Metals and More | Observação de estação |
|---|---|---|
| `researchlab` | 4 iron_ore, 4 log, 4 rocks | override vanilla; confirmar estação atual |
| `researchlab2` | 4 boards, 2 iron_ingot, 2 transistor | override vanilla; confirmar estação atual |
| `birdcage` | 2 papyrus, 1 bronze_ingot, 2 seeds | override vanilla; confirmar estação atual |
| `dragonflychest` | 1 dragon_scales, 4 boards, 2 gold_ingot | override vanilla; confirmar estação atual |
| `compass` | 1 iron_ore, 1 flint | override vanilla; confirmar estação atual |
| `razor` | 2 twigs, 1 iron_ingot | override vanilla; confirmar estação atual |
| `transistor` | 1 cutstone, 1 copper_ingot | override vanilla; confirmar estação atual |
| `lightning_rod` | 1 gold_ingot, 1 cutstone | override vanilla; confirmar estação atual |
| `goldenaxe`, `goldenpickaxe`, `goldenshovel`, `golden_farm_hoe` | 4 twigs, 1 gold_ingot cada | ferramentas de ouro; avaliar como família, sem receita em lote |
| `armormarble` | 12 marble, 4 rope, 1 iron_ingot | override vanilla; confirmar estação atual |
| `portablecookpot_item` | 3 iron_ore, 6 charcoal, 6 twigs | override vanilla; confirmar estação atual |
| `portableblender_item` | 3 iron_ore, 2 transistor, 4 twigs | override vanilla; confirmar estação atual |
| `portablespicer_item` | 3 iron_ore, 3 cutstone, 6 twigs | override vanilla; confirmar estação atual |
| `glasscutter` | 1 boards, 1 moonglass_ingot | conflito conhecido com overrides de outros mods; manter recipe guard |
| `archive_resonator_item` | 1 thulecite, 2 moonglass_ingot | item lunar; avaliar progressão antes de mover |
| `moondial` | 1 bluemooneye, 1 moonglass_ingot, 5 marble | item lunar; avaliar progressão antes de mover |
| `moonrockcrater` | 1 moonglass_ingot, 2 moonrocknugget, 1 marble | item lunar; avaliar progressão antes de mover |
| `moonglassaxe` | 1 moonglass_ingot, 2 twigs, 1 marble | item lunar; avaliar progressão antes de mover |

## 4. Receitas metal-dependentes já movidas ao craftbook

- `minerhat`: 1 strawhat, 1 bronze_ingot, 1 fireflies.
- `cane`: 2 gold_ingot, 1 walrus_tusk, 4 twigs.
- `molehat` e `icehat` usam `transistor`, que por sua vez exige copper_ingot, mas não são itens metálicos em si.
- O craftbook é uma estação diferente da warworkbench. Não mover essas receitas automaticamente sem decidir se o usuário quer que a bancada metalúrgica substitua ou complemente o craftbook.

## 5. Critérios de balanceamento para novas receitas

1. Uma receita por prefab; sem receitas genéricas que fabriquem vários tipos de metal.
2. Preservar a rota de mineração e fundição para obter os lingotes; a bancada fabrica equipamentos/componentes, não substitui o processamento de minério.
3. Custo proporcional à raridade, poder, durabilidade, reparabilidade e estágio de progressão do item.
4. Itens de ruínas/lua/fim de jogo não devem ser antecipados para a bancada inicial.
5. Evitar duplicar receita vanilla ou receita de outro mod; usar `mam/recipe_guard.lua` e preservar alterações externas.
6. Manter autoridade do servidor e compatibilidade multiplayer.
7. Registrar custo original, custo atual, custo proposto e justificativa antes de alterar qualquer receita.

## 6. Pendências de confirmação e testes

- Confirmar no jogo se `warworkbench` é a bancada desejada para todas as receitas metalúrgicas e se deve ser exclusiva ou apenas uma alternativa.
- Confirmar se o pedido inclui somente equipamentos/componentes metálicos ou também recursos brutos/lingotes. Por padrão, este inventário preserva a forja como rota de processamento dos materiais.
- Construir matriz final de estações e níveis de tecnologia após comparar com a versão 2.9.3 e testar filtros no DST.
- Nenhuma receita foi movida ou reequilibrada por este inventário.

## 7. Desconstrução reversível — inventário técnico preliminar

A decisão do usuário permite obter materiais de estágio inferior desconstruindo um material superior; a progressão para cima continua passando pela forja. Os candidatos e a fundamentação estão em `docs/design/METAL_MATERIAL_DECONSTRUCTION.md`.

| Material superior | Retorno canônico candidato | Estado |
|---|---|---|
| `copper_ore` | 2 `copper_dust` | Proposta derivada de 1 copper = 2 × 0,5 |
| `copper_ingot` | 3 `copper_ore` | Proposta derivada de custo 3 copper |
| `iron_ore` | 2 `iron_dust` | Proposta derivada de 1 iron = 2 × 0,5 |
| `iron_ingot` | 3 `iron_ore` | Proposta derivada de custo 3 iron |
| `goldnugget` | 2 `gold_dust` | Proposta derivada de 1 gold = 2 × 0,5 |
| `gold_ingot` | 3 `goldnugget` | Proposta derivada de 3 gold + 3 metal |
| `bronze_ingot` | 3 `copper_ore` + 1 `iron_ore` | Liga composta; proposta derivada das tags |
| `moonglass_ingot` | 2 `moonglass` + 1 `moonrocknugget` | Proposta derivada dos requisitos declarados |
| `adamantium_ingot` | 3 `nightmarefuel` + 1 `iron_ingot` | Liga composta; proposta derivada das tags/requisito nomeado |

**Importante:** nenhuma receita/custo foi alterado. Os retornos ainda precisam de confirmação, escolha da estação e testes. Materiais externos aceitos por tags podem ser normalizados para os componentes canônicos; não se promete reconstruir exatamente a carga original.
