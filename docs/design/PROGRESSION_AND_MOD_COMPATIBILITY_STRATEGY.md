# Metals and More Reforged — design de progressão e compatibilidade entre mods

**Status:** proposta de arquitetura e backlog; não implementada como mudança de gameplay.  
**Data:** 2026-11-09.

## Visão do usuário

Metals and More Reforged deve funcionar como uma camada de progressão metalúrgica e tecnológica para Don't Starve Together. A intenção é alterar de forma coerente o ritmo de acesso a ciência, máquinas, armas e fabricação: um pouco mais de realismo e dificuldade, com etapas mais fragmentadas e dependências significativas, sem transformar o jogo em grind arbitrário. A automação deve criar uma nova forma de jogar e reduzir tarefas repetitivas depois que o jogador construiu e desbloqueou a infraestrutura necessária.

O mod deve preservar sua própria identidade de progressão. Quando mods externos adicionarem itens, armas, ferramentas, máquinas ou receitas, o objetivo é integrar esses conteúdos à progressão metalúrgica do Metals and More, para que não virem atalhos que ignorem a dificuldade ou desorganizem a curva de progressão.

## Princípios de design

1. **Progressão consistente, não bloqueio indiscriminado.** Integrar um item externo na estação/etapa adequada quando fizer sentido; não mover tudo para a forja nem exigir metal sem justificativa.
2. **Compatibilidade pelo lado do Metals and More.** Não editar nem sobrescrever arquivos de outros mods. Usar integração aditiva, adaptadores e APIs públicas/estáveis sempre que possível.
3. **Preservar autoria e intenção do mod externo.** Manter identidade, função, raridade e fantasia do item. Ajustar apenas estação, tecnologia, ingredientes ou pré-requisitos necessários à progressão, com regras explícitas.
4. **Não quebrar receitas de terceiros silenciosamente.** Detectar se receita existe, quem a registrou, seus ingredientes, tech e prototyper. Registrar conflitos e aplicar política segura.
5. **Sem receita duplicada ou custo gratuito.** Não registrar a mesma receita duas vezes, não consumir ingredientes duas vezes, não remover requisitos sem substituição equivalente e não criar loops de lucro.
6. **Compatibilidade opcional e resiliente.** O mod precisa funcionar normalmente quando a dependência externa está ausente, desativada ou em versão desconhecida.
7. **Servidor autoritativo.** Alterações de crafting, inventário, custos, drops e progressão devem ser validadas no servidor; UI do cliente não concede recursos nem desbloqueios.
8. **Configuração transparente.** Opções devem ter descrição, default seguro, versão suportada e consumidor real. Sem opções placebo.
9. **Desempenho previsível.** Fazer descoberta de mods e análise de receitas no carregamento, não em loops por frame ou a cada tentativa de craft.
10. **Compatibilidade baseada em evidência.** Não prometer suporte a toda a Steam Workshop. Manter matriz de mods/versões realmente testados.

## Modelo de integração de receitas externas

Para cada mod reconhecido, manter um adaptador isolado e versionado. O adaptador deve:

- detectar presença e versão quando disponível;
- localizar receitas e prefabs por identificadores estáveis;
- classificar o item por função e tier (básico, intermediário, avançado, raro/especial);
- consultar a matriz de progressão do Metals and More;
- decidir se a receita deve permanecer vanilla/external, receber ingredientes adicionais, mudar de estação/tecnologia ou ser deixada intacta;
- verificar se a receita já foi alterada por outro mod;
- aplicar a mudança uma única vez, sem apagar campos desconhecidos;
- registrar no log a decisão, a versão detectada e o motivo;
- oferecer fallback seguro quando a versão/API não for reconhecida.

**Não** fazer varredura indiscriminada e reescrita de todas as receitas da sessão. Mods podem intencionalmente fornecer itens iniciais, receitas de personagem, conteúdo de evento, itens cosméticos ou alternativas de progressão. Cada regra precisa de classificação e política documentadas.

## Matriz de classificação proposta

| Classe | Exemplos | Política inicial |
|---|---|---|
| Materiais metalúrgicos | minérios, poeiras, fragmentos, lingotes, ligas | usar cadeia metalúrgica própria |
| Ferramentas metálicas | picaretas, machados, ferramentas especiais | estação e tier compatíveis com material e função |
| Armas | armas de metal, projéteis, equipamentos de combate | respeitar raridade, dano, durabilidade e tier; não conceder atalho |
| Máquinas/estações | forjas, máquinas, componentes industriais | progressão por materiais e prototyper apropriados |
| Itens mágicos/especiais | artefatos, itens de evento, itens de personagem | avaliar caso a caso; não forçar metalurgia sem justificativa |
| Cosméticos/decoração | itens sem vantagem funcional | normalmente preservar receita externa |
| Consumíveis | munição, bombas, poções, reparos | avaliar poder, repetibilidade, custo e risco de bypass |

## Fases de implementação

### Fase A — base de progressão
- Inventariar as receitas vanilla e do Metals and More.
- Definir tiers, estações, tecnologias e materiais de cada fase.
- Auditar as bancadas e o que sai da Science Machine para as estações metalúrgicas.
- Produzir matriz de item → receita atual → fonte → tier → estação → custo → proposta → justificativa.

### Fase B — framework de compatibilidade
- Criar registro namespaced de adaptadores por mod.
- Implementar detecção de presença/versão e validação de estrutura das receitas.
- Criar wrappers seguros e idempotentes, com logs de decisão.
- Adotar políticas: preserve (padrão), augment, relocate, replace (somente com contrato explícito).
- Criar testes com receitas ausentes, receitas já modificadas, load order diferente, versão desconhecida e dois adaptadores disputando a mesma receita.

### Fase C — mods grandes prioritários
- Começar com Uncompromising Mode Beta e os mods grandes do conjunto de teste do usuário.
- Adicionar outros mods de armas/itens em adaptadores pequenos e separados.
- Testar cada integração isoladamente e depois em combinações representativas.
- Não adicionar dependência obrigatória de mods externos ao Metals and More.

### Fase D — automação e loop de jogo
- Manter a sequência manual de mineração, processamento e fabricação como caminho-base.
- Integrar baú metalúrgico, W.O.B.O.T./W.I.N.bot e forja como automação construída pelo jogador.
- Respeitar combustível, tempo, alcance, capacidade, estoque mínimo e ordem de produção.
- Automatizar tarefas repetitivas sem gerar recursos, pular etapas ou tornar a progressão instantânea.

## Arquitetura de progressão de forjas já registrada

A progressão anteriormente discutida é:
1. Forja primitiva — metais básicos.
2. Forja reforçada — componentes e ligas.
3. Forja avançada — equipamentos e trinkets.
4. Forja especial — materiais raros e modificações.

A automação programável deve poder definir quantidade fixa, estoque mínimo e ordem contínua. Trinkets podem ter slots por compatibilidade/qualidade. Desconstrução deve retornar materiais de forma proporcional ou fixa, sem lucro ou duplicação, mantendo o avanço de tier exclusivo da forja.

## Ideias futuras preservadas — não confundir com tarefas de bugfix

- Baú metalúrgico abastecendo a forja em conjunto com W.O.B.O.T. e W.I.N.bot.
- Automação programável por quantidade, estoque mínimo e fila/ordem contínua.
- Segunda forja especializada em trinkets visualmente modificáveis, com slots por compatibilidade e qualidade.
- Vacuum Chester como integração nativa/funcionalidade de coleta.
- Cinzeiro infinito como requisito obrigatório da proposta já discutida.
- Tábuas fabricáveis com machado e custos menores, conforme a ideia registrada.
- Bancada para fabricar fios, engrenagens e scrapmetal.
- Desconstrução reversível de materiais por ambos os métodos discutidos, com transação segura e sem lucro/duplicação.
- Receitas de itens metálicos individualizadas na bancada adequada, com custos e tiers balanceados.
- Compatibilidade de progressão com Uncompromising Mode e mods grandes que adicionem armas, itens, ferramentas e máquinas.

Cada ideia deve permanecer no backlog até que seja priorizada e detalhada; registrar não significa autorização para implementar imediatamente.

## Bugs e compatibilidade já conhecidos (separados das ideias)

### Woodie - Better Skill Tree
Histórico de logs de 2026-11-08 apontou:
- Workshop ID: `3516850707`.
- Erro em `modmain.lua:1405`: `attempt to call method 'SetSpellFn' (a nil value)`.
- Ocorreu durante criação do prefab `lucy`, no caminho de inicialização que também envolveu Woodie Transformation Skins, Glassic API e Gem Core.
- O log mostrou erros de leitura de arquivos `mod_config_data` para vários IDs e linhas de encerramento/aborto do servidor. Essas linhas de shutdown não provam, isoladamente, a causa raiz.
- A evidência histórica não prova que a versão atual ainda falha nem que a remoção do hook legado corrigiu o mod externo.

### Mudança já registrada em Metals and More
O PR #20 removeu a ponte global legada de projétil alternativo/Lucy em `scripts/mod_main.lua`, preservando ataques alternativos corpo a corpo e habilidades próprias das armas Forge. O PR #19 havia melhorado wrappers dos componentes de arma. Isso é uma mudança no Metals and More, não uma correção comprovada de `SetSpellFn` no Better Skill Tree.

### Próximo diagnóstico
1. Reabrir os logs antigos e o código correspondente do Better Skill Tree como evidência histórica.
2. Comparar a linha 1405 e a API chamada com a versão de DST usada no log.
3. Inspecionar o fluxo de criação de `lucy` e a ordem de inicialização dos mods envolvidos.
4. Verificar se a versão atual do Metals and More ainda interfere no mesmo fluxo, mesmo após PR #20.
5. Reproduzir em ambiente controlado e testar load orders.
6. Corrigir do lado do Metals and More quando a causa for uma interferência nossa; se o erro for uma chamada inválida dentro do mod externo, criar uma integração defensiva somente se houver ponto de extensão seguro e sem copiar/modificar o mod externo.
7. Não declarar resolvido sem log atual e teste in-game.

## Critérios de aceitação

- Metals and More funciona sozinho.
- Mods externos prioritários mantêm seus itens, mas não criam atalhos indevidos na progressão quando há adaptador suportado.
- Sem adaptador ou com versão desconhecida, o jogo continua carregando e as receitas externas são preservadas.
- Nenhuma receita externa é silenciosamente removida ou duplicada.
- Load order e combinações cobertas têm testes de regressão.
- A automação não cria nem duplica recursos e respeita a progressão.
- O log informa claramente adaptadores aplicados, preservados ou ignorados.
- A matriz pública de compatibilidade lista versões e combinações testadas, sem alegação universal.
