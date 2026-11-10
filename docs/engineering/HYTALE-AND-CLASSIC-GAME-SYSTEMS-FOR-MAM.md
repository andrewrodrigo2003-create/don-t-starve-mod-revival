# Hytale e jogos clássicos — referências de engenharia para Metals and More Reforged

Data da pesquisa: 2026-11-10  
Escopo: pesquisa arquitetural e de design; nenhuma mecânica externa foi copiada e nenhum gameplay do MAM foi alterado.

## Síntese executiva

A melhor lição comum entre Hytale, Factorio, Minecraft e Dwarf Fortress não é adicionar complexidade: é organizar sistemas para que possam evoluir, ser combinados e testados sem efeitos colaterais imprevisíveis.

Para o MAM, as aplicações mais promissoras são:
1. separar dados de receitas/itens da lógica da forja;
2. tornar máquinas orientadas a eventos e estados, não a polling constante;
3. tratar cada operação de forja como uma transação com resultado explícito, consumo, rollback e relatório;
4. modelar encontros, drops e progressão como dados reutilizáveis quando isso reduzir duplicação;
5. construir ferramentas de depuração e cenários de teste independentes do mod distribuído.

## Hytale: arquitetura de conteúdo e ferramentas

### Dados e lógica em camadas
O relatório oficial de modding descreve quatro categorias: plugins de servidor, assets de dados (itens, blocos, NPCs, geração de mundo e loot), assets visuais e arquivos de mundo/prefabs. A divisão ajuda a pensar em limites claros entre comportamento, configuração e apresentação.

**Aplicação ao MAM:** receitas, custos, pesos de previsão, categorias de minério e resultados deveriam ser dados declarativos sempre que possível; funções de execução da forja devem consumir esses dados sem duplicar tabelas de regras em vários arquivos. Isso também facilita testes de tabela e revisão de balanceamento.

### Sistemas conectáveis
A visão oficial do WorldGen V2 enfatiza componentes conectáveis e interoperabilidade entre conteúdo vanilla e modificado. A meta é permitir que componentes simples se combinem em sistemas mais ricos.

**Aplicação ao MAM:** a futura forja, o livro de receitas, o baú metalúrgico e o robô coletor não devem depender de chamadas internas exclusivas uns dos outros. Definir contratos pequenos (entrada, saída, estado, evento concluído, erro) reduz acoplamento. No DST isso precisa respeitar APIs e limites reais do jogo; não presumir multithreading ou APIs de Hytale.

### Encontros como conteúdo
O Encounter Manager de Hytale coordena fases, ondas e mudanças de arena através de definições de encontro, permitindo reutilizar a infraestrutura entre chefes.

**Aplicação ao MAM:** útil como padrão conceitual para futuras sequências de forja ou eventos de máquinas: um controlador de estados genérico e dados específicos por cenário. Não é prioridade imediata nem justificativa para criar um framework pesado.

### Ferramentas de autoria e iteração
Hytale aponta para editores de nós, ferramentas de assets, preview e workflows de iteração. A lição prática é encurtar o ciclo editar → executar → observar → corrigir.

**Aplicação ao MAM:** manter harnesses pequenos, relatórios reproduzíveis, artefatos de CI e uma ferramenta QA opt-in separada do mod de produção. O runner L4 já desenhado é um passo coerente nessa direção.

## Jogos clássicos e sistemas maduros

### Factorio — ciclo de vida e eventos
A API oficial separa as etapas settings, prototype e runtime. A etapa runtime é orientada a eventos. Essa separação força o modder a distinguir configuração/protótipos da lógica executada durante o jogo.

**Aplicação ao MAM:** organizar inicialização, registro de receitas e execução em jogo como fases distintas. Preferir callbacks/eventos e tarefas agendadas com lifecycle explícito a loops frequentes. Em DST, seguir o lifecycle nativo e confirmar APIs na versão alvo; não transplantar a API do Factorio.

### Minecraft — custo de ticks e trabalho sob demanda
A documentação comunitária sobre ticks descreve como entidades, block entities, atualizações de redstone e verificações frequentes contribuem para custo de simulação. Componentes como hoppers podem gerar verificações repetidas, e mecanismos desativados ou trabalho agendado podem reduzir carga.

**Aplicação ao MAM:** evitar varrer inventários/entidades continuamente; reagir a mudanças de container, abertura/fechamento e eventos da máquina. Para qualquer automação futura, medir quantidade de entidades, callbacks, tasks e custo por ciclo. Não assumir que a arquitetura de ticks do Minecraft é igual à do DST.

### Dwarf Fortress — simulação rica e coerência sistêmica
A tradição de desenvolvimento de Dwarf Fortress mostra o valor de sistemas que interagem e geram consequências emergentes. A lição não é simular tudo: é manter regras locais coerentes e observáveis.

**Aplicação ao MAM:** a metalurgia deve ter regras previsíveis e explicáveis: quais materiais foram aceitos, por que uma combinação é inválida, quanto foi consumido, o que foi devolvido e qual produto foi criado. Evitar efeitos ocultos e mensagens que não correspondam ao estado real.

## Diretrizes de arquitetura propostas para o MAM

### 1. Forja como máquina de estados
Estados conceituais: idle, validating, processing, completed, rejected, rollback. Transições devem ocorrer por eventos reais do container/tarefa, com cancelamento e limpeza no fechamento/destruição da entidade. O nome dos estados é proposta, não contrato implementado.

### 2. Operação transacional
Antes de consumir itens, calcular e registrar a intenção da operação. Em seguida, validar inventário e regra; só então executar consumo e produção. Se a operação falhar, devolver os itens conforme snapshot/registro confiável. Evitar anunciar rollback se não houve perda real. Testar duplicação, perda e save/load.

### 3. Dados declarativos com validação
Manter definições de receitas/resultados em uma fonte de dados única. Validar no CI: prefab de resultado existe, quantidades são válidas, materiais não se contradizem, receitas duplicadas são sinalizadas e todas as imagens referenciadas existem. Preservar regras de compatibilidade com UM Beta.

### 4. Eventos e lifecycle
Todo listener, task e widget precisa de dono e rotina de cleanup. Sem polling por frame para observar inventário/estado. Tasks devem ser finitas, canceláveis e não duplicadas. A UI cliente deve receber apenas os dados necessários.

### 5. Observabilidade
Logs estruturados devem registrar ID/categoria do cenário, máquina, transição, entrada, saída, motivo de rejeição e rollback. Instrumentação pesada fica em QA/profiling, não na build de produção. Medir baseline e carga antes de declarar otimização.

### 6. Testes em camadas
- L0: parsing, lint e análise estática.
- L1: funções puras de receitas, custos, previsões e validação.
- L2: contratos de componentes e wrappers.
- L3: harnesses com stubs e simulação de lifecycle.
- L4: execução dentro do motor DST, mundo descartável.
- L5: multiplayer e pilha real de mods, incluindo UM Beta.

CI verde não equivale a L4/L5.

## Prioridades e limites

Prioridade alta:
- revisar a PR da prévia visual da forja com foco em resultado ambíguo neutro, lifecycle de widgets e atualização por eventos;
- mapear e testar consumo/devolução como transação;
- continuar o runner L4 isolado e a auditoria de contratos de combate;
- manter otimizações do minimapa isoladas em PR e exigir benchmark/runtime antes de afirmar ganho real.

Não fazer agora:
- não criar uma engine genérica de máquinas;
- não adicionar automação de grande escala só porque Hytale/Factorio têm sistemas expansivos;
- não importar APIs ou código de outro jogo;
- não alterar balanceamento, dano, receitas ou comportamento de gameplay sem evidência e aprovação;
- não afirmar compatibilidade runtime a partir de análise estática.

## Fontes primárias e referências

- Hytale, Modding Strategy and Status (20 Nov 2025): https://hytale.com/news/2025/11/hytale-modding-strategy-and-status
- Hytale, The Future of World Generation (5 Jan 2026): https://hytale.com/news/2026/1/the-future-of-world-generation
- Hytale, First Look: Chapter 1 and More (16 Jul 2026): https://hytale.com/news/2026/7/first-look-chapter-1-and-more
- Factorio 2.1 API docs — API lifecycle: https://lua-api.factorio.com/latest/index.html
- Minecraft Wiki — Game tick: https://minecraft.wiki/w/Game_tick
- Minecraft Wiki — Block entity: https://minecraft.wiki/w/Block_entity
- Dwarf Fortress developer interviews index: https://dwarffortresswiki.org/index.php/Developer_interviews

## Proveniência

Pesquisa de arquitetura e documentação pública. As propostas de aplicação ao MAM são inferências de engenharia, não recursos implementados nem testes executados. Confirmar toda API DST contra os scripts da build instalada antes de implementar.
