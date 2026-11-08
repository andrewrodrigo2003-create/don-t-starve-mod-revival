# Desconstrução reversível de materiais metalúrgicos

**Status:** especificação preliminar baseada nas receitas atuais; ainda não implementada.  
**Data:** 2026-11-08.  
**Escopo:** Metals and More Reforged.

## 1. Objetivo confirmado pelo usuário

Permitir que o jogador desconstrua um material metalúrgico de estágio superior para recuperar o estágio anterior, em uma lógica de qualidade de vida inspirada no Minecraft. O caminho de avanço continua sendo a forja: a bancada não deve fabricar livremente materiais para subir a cadeia.

O uso principal é corrigir excesso de produção e erros de cálculo, recuperando materiais em vez de obrigar o jogador a descartar o excedente ou minerar tudo novamente.

## 2. Cadeias observadas no código atual

Fontes auditadas:
- `scripts/smelting.lua`: tags e valores dos ingredientes.
- `scripts/smelting_products.lua`: produtos, testes, prioridades e custos por unidade.
- `scripts/prefabs/metal_dusts.lua`: prefabs de poeira.
- `scripts/prefabs/metals.lua`: criação dos produtos da metalurgia.

| Família | Estágio baixo | Estágio intermediário | Estágio superior | Base observada |
|---|---|---|---|---|
| Cobre | `copper_dust` (0,5 copper) | `copper_ore` (1 copper) | `copper_ingot` (custo 3 copper) | 2 poeiras equivalem a 1 unidade de tag; 3 unidades de tag para 1 lingote |
| Ferro | `iron_dust` (0,5 iron) | `iron_ore` (1 iron) | `iron_ingot` (custo 3 iron) | Mesma escala de cobre |
| Ouro | `gold_dust` (0,5 gold) | `goldnugget` (1 gold) | `gold_ingot` (3 gold + 3 metal) | Nugget fornece 1 gold e 1 metal |
| Bronze | — | componentes de cobre + ferro | `bronze_ingot` (3 copper + 1 iron) | Liga composta; não é uma cadeia de um único material |
| Vidro lunar | `moonglass` e `moonrocknugget` | — | `moonglass_ingot` (2 moonglass + 1 moon) | Receita também exige o componente lunar |
| Adamantium | `nightmarefuel` (1 steel) + `iron_ingot` nomeado | — | `adamantium_ingot` (3 steel + 1 iron_ingot) | Liga composta; o ferro é requisito nomeado |

Observações:
- A forja aceita ingredientes por tags, não apenas por um prefab único. Poeiras, minérios e outros itens registrados podem contribuir para o mesmo total de tags.
- O teste de `gold_ingot` exige simultaneamente 3 gold e 3 metal. O `goldnugget` atual fornece ambos.
- A receita de `moonglass_ingot` verifica presença de moon e pelo menos 2 moonglass; a tabela de custo declara 2 moonglass e 1 moon por unidade.
- `adamantium_ingot` exige 3 steel e uma unidade nomeada de `iron_ingot`.
- `junk_dust` é um produto de baixa prioridade obtido de ingredientes com tag metal; não é uma etapa simples de uma cadeia de metal e não deve ganhar receita de desconstrução sem regra própria.
- Gemas e fragmentos não entram automaticamente nesta matriz: são uma família separada e exigem análise própria.

## 3. Retornos candidatos para desconstrução

A tabela abaixo traduz os custos atuais para componentes canônicos de um estágio inferior. São candidatos derivados dos dados do código, não valores já implementados nem autorização para mudar receitas.

| Material desconstruído | Retorno candidato | Justificativa |
|---|---|---|
| `copper_ore` | 2 `copper_dust` | 1 copper = 2 poeiras de 0,5 |
| `copper_ingot` | 3 `copper_ore` | custo atual de 3 copper |
| `iron_ore` | 2 `iron_dust` | 1 iron = 2 poeiras de 0,5 |
| `iron_ingot` | 3 `iron_ore` | custo atual de 3 iron |
| `goldnugget` | 2 `gold_dust` | 1 gold = 2 poeiras de 0,5 |
| `gold_ingot` | 3 `goldnugget` | 3 gold e 3 metal são fornecidos por 3 nuggets |
| `bronze_ingot` | 3 `copper_ore` + 1 `iron_ore` | reproduz os componentes de tag da liga |
| `moonglass_ingot` | 2 `moonglass` + 1 `moonrocknugget` | reproduz os requisitos declarados na receita/custo |
| `adamantium_ingot` | 3 `nightmarefuel` + 1 `iron_ingot` | reproduz 3 steel e o requisito nomeado de ferro |

A equivalência de tags não garante recuperar exatamente os mesmos prefabs que o jogador colocou originalmente. Por exemplo, uma receita de lingote pode aceitar poeira, minério ou outros ingredientes compatíveis. A desconstrução retornaria componentes canônicos, de forma previsível, e não tentaria reconstruir o histórico de entrada.

## 4. Regras de segurança e balanceamento

1. Desconstruir consome o item superior e entrega somente o retorno explicitamente registrado para aquele prefab.
2. Avançar novamente para o próximo estágio continua exigindo a forja e suas receitas, tempo e custos normais.
3. Não permitir conversões genéricas baseadas apenas na tag `metal`; cada prefab precisa de uma regra explícita.
4. Materiais compostos devolvem os componentes específicos da receita, não um material universal.
5. A operação deve ser atômica no servidor: ou consome o item e entrega todos os retornos, ou não altera inventário algum.
6. Se não houver espaço para todos os retornos, a ação deve falhar sem consumir o material; alternativa de drop no chão só pode ser adotada se for segura e intencional.
7. Nunca gerar retorno parcial por erro de spawn, desconexão ou falha de inventário.
8. A receita de desconstrução não deve poder ser usada para fabricar um estágio superior; o fluxo de subida permanece exclusivo da forja.
9. Testar conversão repetida, pilhas, inventário cheio, baú metálico, interrupção, save/load e multiplayer.
10. Preservar compatibilidade com receitas e ingredientes externos: não alterar tags nem código de outros mods.

## 5. Estação recomendada e decisão pendente

Recomendação inicial: usar a `warworkbench` (Armory / `ALCHEMY_ONE`) como estação de desconstrução, mantendo a forja metalúrgica como única rota de avanço. Isso aproveita a estação existente e separa claramente fabricar/desmontar de fundir/processar.

Antes da implementação, confirmar se o usuário prefere:
- desconstrução na bancada de guerra já existente; ou
- desconstrução na própria forja metalúrgica, com um modo/receita separado.

Não criar uma nova estação apenas para esta função sem necessidade demonstrada.

## 6. Fora do escopo nesta etapa

- Não converter equipamentos metálicos em lingotes automaticamente: isso exigiria regras próprias de durabilidade, componentes, valor e perda.
- Não desconstruir ligas, gemas ou sucata fora dos casos explicitamente mapeados.
- Não alterar custos atuais de fundição para acomodar a desconstrução.
- Não mudar receitas de outros mods nem editar Uncompromising Mode.
- Não declarar a funcionalidade pronta antes de implementação e testes.

## 7. Próxima etapa técnica

Após a escolha da estação, criar uma tabela de retorno final, implementar um pequeno conjunto vertical de receitas (cobre/ferro/ouro), adicionar testes de inventário e transação e só então expandir para bronze, vidro lunar e adamantium. A expansão deve preservar a composição de cada liga e validar o comportamento real do DST.
