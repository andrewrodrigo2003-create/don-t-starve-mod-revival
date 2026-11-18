# Wilson — integração de transmutação com Metals and More

**Data:** 2026-11-18  
**Status:** pesquisa de compatibilidade e regra de projeto; receitas MAM de transmutação ainda não implementadas.

## Decisões do projeto já estabelecidas

- A desconstrução de materiais usa recuperação padrão de **75% por etapa**.
- Wilson recupera **100% de todos os materiais** na desconstrução.
- Winona recupera **100% de materiais não mágicos**.
- Maxwell recupera **100% de materiais mágicos de escuridão**.
- A transmutação de Wilson é uma habilidade própria, distinta da desconstrução e da metalurgia, e deve depender do aprendizado das habilidades pertinentes.
- A cadeia de desconstrução permanece reversa e por etapas: barra/lingote → minério bruto → poeira. Ligas devolvem seus componentes correspondentes.

A PR #65 implementa os perfis de recuperação acima e a allowlist de materiais. Isso não implementa a habilidade separada de transmutação.

## Compatibilidade com a árvore vanilla de Wilson

A documentação da árvore de habilidades baseada no build DST 722832 (atualizada em 2026-04-28) identifica a categoria Alchemy e a seguinte progressão de nós:

| Nó | Função vanilla documentada |
|---|---|
| `wilson_alchemy_1` | Transmutation, raiz da categoria Alchemy |
| `wilson_alchemy_3` | Transmute Ore I |
| `wilson_alchemy_7` | Transmute Ore II |
| `wilson_alchemy_8` | Transmute Ore III |

O espelho público do script `prefabs/skilltree_wilson.lua` confirma a topologia: `wilson_alchemy_1` é raiz e conecta aos ramos de alquimia; `wilson_alchemy_3` conecta a `wilson_alchemy_7`, que conecta a `wilson_alchemy_8`.

A API documentada do componente `skilltreeupdater` oferece `inst.components.skilltreeupdater:IsActivated(skill)`. O script vanilla espelhado usa o mesmo método para verificar habilidades ativas. O servidor MAM deve validar a habilidade no momento da ação, sem confiar apenas em UI ou estado enviado pelo cliente.

## Regra técnica recomendada

1. Reutilizar a árvore Alchemy vanilla; não criar uma árvore paralela para Wilson.
2. Usar `skilltreeupdater:IsActivated(...)` no servidor, verificando existência do componente e do método antes da chamada.
3. Manter a transmutação separada da ação `MAM_DECONSTRUCT_METAL`: desconstrução recupera componentes com perda de 25%; transmutação é uma conversão ativa de uma família de materiais e precisa de receitas próprias.
4. Não conceder a outros sobreviventes a transmutação de Wilson por meio dos perfis de recuperação.
5. Não permitir que transmutação ignore custos, gere progressão gratuita ou substitua a forja como rota normal de fabricação.
6. Registrar e testar cada conversão em uma tabela explícita, incluindo custo de entrada, saída, tier de habilidade, estação/condição, limites por ação e prevenção de ciclos lucrativos.

## Ponto ainda não especificado

As decisões recuperadas confirmam que Wilson deve ter transmutação, mas não enumeram quais conversões MAM concretas devem existir. Portanto, não inventar uma tabela de receitas nesta etapa. A implementação de runtime fica pendente da definição de conversões e de seus custos. O uso de `wilson_alchemy_8` como requisito para conversões metálicas de tier alto é uma proposta de balanceamento, não uma decisão aprovada.

## Fontes técnicas

- [Wilson skill tree — DST Vanilla API, build 722832](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/skilltree_wilson)
- [SkillTreeUpdater — DST Vanilla API, build 722832](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/skilltreeupdater)
- [Espelho público do script skilltree_wilson.lua](https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/skilltree_wilson.lua)
- [Espelho público de skilltreedata.lua](https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/skilltreedata.lua)

Os espelhos são fontes comunitárias de referência, não distribuição oficial da Klei. Confirmar os identificadores e a API no build DST efetivamente usado antes de publicar ou declarar compatibilidade final.

## Validação pendente

- Contrato de servidor para cada habilidade de transmutação.
- Testes de conversão com custo físico exato e prevenção de ciclos.
- Save/load e multiplayer.
- Compatibilidade com UM Beta e mods que alterem skill trees.
- Teste real no DST.
