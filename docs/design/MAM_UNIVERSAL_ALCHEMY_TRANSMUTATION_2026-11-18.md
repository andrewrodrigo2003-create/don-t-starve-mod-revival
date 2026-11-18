# Metals and More — transmutação universal no Laboratório de Alquimia

**Data:** 2026-11-18  
**Status:** direção de projeto confirmada; tabela de conversões e implementação de runtime ainda em desenvolvimento.

## Decisão confirmada pelo usuário

A transmutação de minérios é uma mecânica geral do Metals and More, disponível a **todos os sobreviventes**, sem exigir Wilson, árvore de habilidades, personagem específico ou desbloqueio individual de skill.

O ponto central para executar a transmutação será o **Mad Scientist Lab** vanilla (`madscience_lab`), chamado aqui de **Bancada/Laboratório de Alquimia**. O MAM deverá permitir fabricar essa bancada a qualquer momento, independentemente do evento Hallowed Nights estar ativo. A bancada também poderá receber outras funções alquímicas futuras, além da transmutação de minérios.

A implementação não deve depender de `TECH.HALLOWED_NIGHTS`, de `wilson_alchemy_*` ou de `skilltreeupdater:IsActivated` para disponibilizar a função. Wilson não terá privilégio exclusivo. A mesma regra de acesso vale para todos os personagens.

## Distinção entre sistemas

- **Desconstrução:** desfaz um item metálico e devolve os materiais de origem, com as regras de recuperação próprias.
- **Transmutação:** converte deliberadamente um minério/material metálico em outro, mediante uma receita/custo explícito e usando a Bancada de Alquimia.
- **Metalurgia:** processa materiais em poeiras, lingotes, ligas e equipamentos na cadeia normal de fabricação.

Essas mecânicas devem permanecer separadas em código, UI, logs e testes. Transmutação não pode virar um atalho para recuperar 100% dos ingredientes de uma receita nem criar ciclos de conversão lucrativos.

## Bancada e disponibilidade fora do evento

A referência vanilla identifica o prefab e a estação como:

- Prefab/recipe ID: `madscience_lab`.
- A estação é registrada como crafting station (`PROTOTYPER_DEFS.madscience_lab`) e seu prefab possui o componente especializado `madsciencelab`.
- O vanilla associa sua receita de construção a `TECH.HALLOWED_NIGHTS` e ao aviso `NEEDSHALLOWED_NIGHTS`; essa restrição sazonal não atende ao projeto.
- O MAM deverá registrar/ajustar a receita da bancada para que seja fabricável em qualquer mundo e época, sem depender do evento sazonal. A implementação deve preservar o prefab/visual vanilla e evitar registrar uma segunda estrutura duplicada.
- A bancada deve expor as receitas MAM de transmutação por meio do fluxo de crafting station apropriado. Não basta adicionar receitas comuns ao filtro se o prototyper não as disponibilizar no contexto da estação.

O código atual do MAM já registra tecnologias próprias (`ALCHEMY`, `CRAFTSBOOK`, `MAM_FORGE`) e utiliza `AddRecipe2` e filtros de crafting station. A implementação deve seguir os helpers e contratos existentes, em vez de criar um sistema paralelo ou alterar globalmente o comportamento de outras estações.

## Comportamento específico do Mad Scientist Lab

A documentação do prefab vanilla mostra que `madscience_lab` não é apenas uma bancada de crafting comum: possui o componente `madsciencelab`, com fluxo de experimento em etapas, callbacks de início/conclusão e resultados vanilla baseados em tabelas ponderadas. O método `StartMakingScience(product, name)` inicia esse fluxo; o callback vanilla de conclusão escolhe resultados de experimento.

Consequência para o MAM: **não reutilizar diretamente a tabela aleatória de resultados vanilla como motor da transmutação**, pois cada conversão de minério precisa ser determinística e consumir exatamente os materiais escolhidos pelo jogador. A implementação deve criar uma operação MAM própria, validada no servidor, e integrar a apresentação/animação da bancada sem sobrescrever globalmente as experiências Hallowed Nights. Se o componente vanilla não oferecer um ponto de extensão seguro para isso, usar uma ação/componente MAM dedicado associado ao prefab, preservando o fluxo original de Halloween.

A receita da bancada também precisa ser disponibilizada fora do evento sem depender de `TECH.HALLOWED_NIGHTS`/hint sazonal. Antes de sobrescrever ou re-registrar a receita vanilla, verificar a ordem de carregamento e o contrato de `AddRecipe2`/RecipePostInit no build alvo, para evitar duplicidade ou conflito com outros mods.

## Contrato funcional pretendido

1. Qualquer sobrevivente pode usar a Bancada de Alquimia.
2. A bancada pode ser fabricada em qualquer momento, mesmo com Hallowed Nights desativado.
3. A transmutação só ocorre na bancada; não é uma habilidade portátil ou uma receita de crafting livre.
4. Cada conversão declara entradas, quantidades, saída, quantidade produzida e requisitos/custos adicionais.
5. A operação valida no servidor os itens realmente disponíveis e consome os custos uma única vez.
6. A UI mostra claramente o resultado e o custo antes da confirmação; falhas não consomem materiais.
7. Receitas não criam loops de lucro nem substituem a forja/metalurgia como rota principal de progressão.
8. O desenho da bancada deve permitir adicionar no futuro outras operações alquímicas sem acoplar tudo ao código de minérios.

## Regras de desconstrução já estabelecidas — permanecem independentes

- Recuperação padrão: **75% por etapa**.
- Wilson: 100% de recuperação de todos os materiais na desconstrução.
- Winona: 100% de recuperação de materiais não mágicos.
- Maxwell: 100% de recuperação de materiais mágicos de escuridão.
- Cadeia reversa por etapas: barra/lingote → minério bruto → poeira; ligas devolvem seus componentes correspondentes.

Esses perfis não concedem nem restringem a transmutação. A transmutação é universal e usa apenas os custos definidos em sua própria tabela de receitas.

## Conversões e balanceamento ainda pendentes

Nenhuma matriz completa de conversões metálicas foi aprovada. Antes de implementar, cada receita precisa ser avaliada com base em:

- tier e raridade do material de origem e destino;
- abundância real no mundo e fontes de obtenção;
- custos de catalisadores, energia/essência ou materiais auxiliares, quando fizer sentido;
- proporção de entrada/saída e risco de ciclos;
- impacto em progressão inicial, média e tardia;
- compatibilidade com Uncompromising Mode Beta e outros mods de metais/minérios.

Não assumir conversões gratuitas, proporções 1:1 ou receitas específicas como decisões aprovadas. A matriz deve ser pesquisada e balanceada antes do runtime.

## Referências técnicas

- [Mad Scientist Lab / Hallowed Nights — Don't Starve Wiki](https://dontstarve.wiki.gg/wiki/Hallowed_Nights)
- [Mad Science Filter — Don't Starve Wiki](https://dontstarve.wiki.gg/wiki/Mad_Science_Filter)
- [Madscience Lab prefab/component — DST Vanilla API](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/madscience_lab)
- [Crafting technology and item lifecycles — Game Design Lab](https://teemo.dev/game-design/dont-starve-together/systems/crafting/)
- [Vanilla recipes.lua mirror — PROTOTYPER_DEFS and madscience_lab recipe](https://github.com/BadWolf22/Dont-Starve-Together-Scripts/blob/master/recipes.lua)
- [DST Vanilla API — Recipes / PROTOTYPER_DEFS](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/recipes)

Os scripts consultados são espelhos comunitários/documentação de referência, não distribuição oficial da Klei. Confirmar comportamento e assinatura no build DST usado pelo projeto antes de declarar compatibilidade final.

## Validação pendente

- Disponibilidade da bancada com Hallowed Nights ativo e inativo.
- Craft da bancada por todos os sobreviventes, incluindo Wickerbottom e personagens modded.
- Acesso às receitas pela crafting station em multiplayer (cliente/servidor).
- Consumo atômico de ingredientes, falhas, cancelamento e save/load.
- Testes de proporções e prevenção de ciclos lucrativos.
- Compatibilidade com UM Beta e mods que alterem crafting filters, recipes ou Mad Science Lab.
- Teste real no DST; CI/simuladores não substituem runtime.
