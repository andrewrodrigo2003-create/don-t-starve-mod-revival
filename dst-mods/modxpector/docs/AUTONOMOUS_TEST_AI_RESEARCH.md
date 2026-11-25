# ModXpector — Pesquisa e arquitetura da IA autônoma offline

**Data:** 2026-11-25  
**Escopo:** pesquisa técnica para a IA embarcada do ModXpector / DST Mod Test Lab.  
**Status:** pesquisa inicial consolidada; implementação e validação in-game ainda pendentes.  
**Branch de trabalho:** `security/modxpector-5.0.14-opt-in-2026-11-23` (PR #76, draft).

## 1. Decisão arquitetural

A IA principal deve permanecer embarcada no próprio mod, em Lua 5.1, sem exigir Ollama, Python, FastAPI, servidor local, modelo baixado, API, chave, assinatura ou serviço externo durante a execução.

A solução viável neste ambiente é uma **IA especializada simbólica/heurística**, não um LLM generativo geral. Ela pode receber comandos por botão e por chat usando um interpretador de intenções com vocabulário e gramática controlados, converter pedidos em objetivos e planos, observar o jogo, executar testes autorizados e verificar pós-condições. Não deve ser apresentada como equivalente a uma conversa irrestrita com ChatGPT. Um chatbot de linguagem aberta com capacidade geral exigiria um modelo generativo; embutir um LLM moderno em Lua puro dentro do runtime DST não é uma premissa realista para este projeto.

## 2. Pesquisa de projetos DST

### 2.1 Artificial Wilson / KingOfTown DS-AI
- Repositório: https://github.com/KingofTown/DS-AI
- Código estudado: `scripts/brains/artificalwilson.lua`.
- Padrões observados: Behavior Trees hierárquicas, nós especializados para fome/saúde/sanidade, coleta, colheita, corte/mineração, luz, cozinha, inventário, combate, fuga, construção e recuperação de personagem preso.
- O agente usa prioridades e condições do mundo para escolher a próxima ação; ações do jogo são encapsuladas em comportamentos.
- Repositório antigo (criado em 2015); licença não identificada na página/arquivos verificados nesta pesquisa.
- Decisão: referência conceitual; não copiar código, assets ou trechos sem licença/permissão compatível.

### 2.2 FAtiMA-DST / Walter
- Repositório: https://github.com/hineios/FAtiMA-DST
- Oficina Walter: https://steamcommunity.com/sharedfiles/filedetails/?id=1339264854
- O mod separa corpo (Lua/DST) e cérebro (aplicativo C# FAtiMA-Server). O ciclo é percepção → transmissão → decisão → ação → nova percepção.
- O modelo de crenças representa necessidades, posição, entidades observadas, inventário, equipamentos, receitas e estado do mundo.
- O artigo acadêmico descreve uso de Behavior Trees e Buffered Actions para executar ações e validar pré-condições como possuir ferramenta adequada.
- O repositório declara MIT, mas sua arquitetura depende de servidor externo e não atende ao requisito de runtime independente.
- Decisão: aproveitar os conceitos de crenças, percepção, ações verificáveis e separação cérebro/executor; não adicionar servidor externo.

### 2.3 DST Agent
- Repositório: https://github.com/johnturner108/dst-agent-brain
- Oficina: https://steamcommunity.com/sharedfiles/filedetails/?id=3545890282
- Aceita instruções por chat, usa LLM em servidor Python e depende de API/modelo, além de mods auxiliares para filas de ações e navegação.
- A própria descrição relata limitações e relatos de respostas sem execução.
- Decisão: referência para UX de chat e ciclo intenção→ação; arquitetura externa excluída.

### 2.4 Dev Tools
- Repositório: https://github.com/dstmodders/mod-dev-tools
- Oficina: https://steamcommunity.com/sharedfiles/filedetails/?id=2220506640
- O repositório declara licença MIT e oferece UI de depuração, seleção de entidades, inspeção de dados e API/extensibilidade.
- Decisão: referência de interface e integração opcional. Não é dependência obrigatória; não copiar código nesta etapa.

### 2.5 Outras referências
- Friendly Skeleton - AI (Workshop 2323760467): agentes especializados; o adaptador atual do ModXpector só testa aproximação a um prefab já existente e confirmado no runtime. Não certifica as demais capacidades.
- NPC Friends (Workshop 3684000581): descrição consultada anuncia vários companheiros e tarefas; disponibilidade/estado da página e licença de código não foram confirmados. Não integrar como dependência.
- Crash Never Mind (Workshop 3377689002): anuncia diagnóstico assistido por IA, mas declara uso de computação em nuvem; não satisfaz o requisito offline.
- Pesquisa acadêmica: https://raw.githubusercontent.com/hineios/dissertation/master/dissertation-paper/dissertation-paper.pdf — descreve entidades, prefabs, componentes, brains, crenças e execução por Behavior Tree/Buffered Actions.

## 3. Fundamentos técnicos DST

- O DST representa atores e objetos como entidades criadas a partir de prefabs; componentes implementam capacidades e estado; brains/Behavior Trees definem comportamento.
- O runtime possui infraestrutura de Behavior Tree (Selector, Sequence, Condition, Action, Priority, Event e outros nós).
- A execução de ações deve usar o pipeline nativo de ações/BufferedAction e respeitar autoridade cliente/Master. Não criar jogador de rede falso nem contornar validações do servidor.
- Hooks de observação devem ser passivos, limitados e opt-in. Não substituir globais/funções de outros mods, interceptar `print`, `error`, `pcall` ou `xpcall`, nem modificar comportamento dos mods-alvo.
- Referência de API (não substitui os scripts do build instalado): https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/behaviourtree
- Orientação oficial Klei: https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together. A Klei exige respeito a licenças/permissões e não presume autorização de reutilização quando ela não está explicitada.

## 4. Arquitetura-alvo do agente

1. **Interface:** botão Analisar, botão Executar testes controlados, parar/cancelar e entrada de chat.
2. **Interpretador de intenção:** normaliza comandos conhecidos (ex.: analisar mods, testar mod X, testar receitas, verificar inventário, parar). Resolve entidades/IDs com confirmação quando houver ambiguidade. Comandos desconhecidos devem gerar pergunta/explicação, não execução aproximada.
3. **Memória de sessão:** objetivo, plano, etapa atual, tentativas, evidências, resultados, limites e histórico recente. Dados limitados e sanitizados.
4. **Percepção:** inventário de mods, estados de carregamento, dependências, flags, erros capturados por fontes autorizadas, prefabs/receitas/componentes observados e eventos opt-in.
5. **Conhecimento:** catálogo interno de regras DST, assinaturas de erros, padrões de API e adaptadores de mods comunitários. Cada regra deve ter origem, versão/build, confiança, pré-condições e evidência.
6. **Planejador:** Behavior Tree stateful + utility scoring. Separa objetivo, tarefa, ação e verificação. Replaneja quando pré-condição muda, alvo desaparece, ação falha ou limite é atingido.
7. **Executor Virtual Player:** usa ações nativas permitidas, RPC validada pelo Master e limites por plano. Cada efeito no mundo exige allowlist, pré-condição, pós-condição e timeout.
8. **Verificador independente:** não aceita o retorno da ação como prova de sucesso; consulta estado observável após a ação. Estados: passed, failed, inconclusive, blocked e timeout.
9. **Relatório:** objetivo solicitado, cenário, ações, evidências, duração, falhas, confiança, limitações e próxima ação sugerida.

## 5. Política de execução segura

- Padrão: análise somente leitura.
- Testes com efeitos no mundo: opt-in explícito, administrador quando exigido, mundo/staging descartável e botão de parada.
- Nunca testar destruição, combate, consumo, construção, spawn, drop ou alterações persistentes em mundo de produção sem perfil de teste isolado e aprovação explícita.
- Cada ação tem limite de repetição, timeout, alvo restrito e verificador próprio.
- Falha de observação não significa sucesso nem falha do mod: registrar inconclusivo.
- Suite comunitária é dado declarativo; não executar funções/callbacks/código Lua de outros mods.
- Nenhum adaptador deve ser considerado compatível apenas porque o prefab existe; validar a ação e sua pós-condição.
- Preservar logs e relatórios; não modificar arquivos/configurações dos mods examinados.

## 6. Plano de evolução do Virtual Player

Expandir por famílias, não liberar a allowlist inteira de uma vez:

1. **Observacionais:** aproximar-se, localizar entidade, confirmar distância, verificar tags/estado.
2. **Inventário reversível em staging:** localizar item, equipar/desequipar e mover entre inventário/contêiner com contagem antes/depois.
3. **Coleta e trabalho:** PICK/PICKUP/HARVEST/CHOP/MINE/DIG/HAMMER; confirmar alteração de quantidade/vida útil e ferramenta.
4. **Crafting:** validar receita, ingredientes, estação, tecnologia, criação e produto final.
5. **Sobrevivência:** comida, combustível, luz, temperatura e necessidades; só em mundo descartável.
6. **Combate e eventos:** por último, com alvos controlados, limites rígidos e sem jogadores/entidades de produção.

Cada etapa exige: teste unitário Lua 5.1, contrato de plano, simulação/mocks, verificação de segurança, teste de regressão e evidência in-game antes de subir o nível de confiança.

## 7. Chat offline: escopo realista

O chat pode funcionar sem modelo externo por um parser de comandos/intenções:
- `/mx analisar`
- `/mx testar <mod_id>`
- `/mx testar inventario`
- `/mx testar receitas <mod_id>`
- `/mx status`
- `/mx parar`

Também pode aceitar frases naturais dentro de um conjunto controlado de verbos, objetos e parâmetros. O parser deve produzir uma intenção estruturada, nunca executar texto arbitrário. A UI deve mostrar a interpretação antes de iniciar ações com efeitos. Conversa livre, conhecimento geral ilimitado e geração textual aberta não são promessas deste motor offline.

## 8. Estado real do código na PR #76

Branch: `security/modxpector-5.0.14-opt-in-2026-11-23`  
HEAD observado: `9496f104c932bb5b7cdeb86352c73ffe9659d78b`  
PR #76: draft/open, sem merge.

Já existe:
- `embedded_ai.lua`: regras diagnósticas, evidência/confiança, plano read-only, executor interno, seleção/validação de suites, Behavior Tree stateful.
- `runtime_observer.lua`: hooks opt-in limitados.
- `world_inventory.lua`: snapshots limitados de prefabs, receitas e componentes.
- `virtual_player_client.lua`: executor client-side usando pipeline de ação, allowlists e pós-condições.
- API declarativa de suites comunitárias e aprovação do Master.
- Testes Lua 5.1, contratos e empacotamento em CI.

Limitações atuais confirmadas:
- A IA é simbólica/heurística; não é LLM.
- A API pública de suites comunitárias continua limitada a WALKTO e verificações observacionais.
- O código do Virtual Player reconhece mais ações, mas isso não significa que cada ação esteja liberada/validada pela API comunitária ou pelo Master.
- Retirada por slot de contêiner ainda requer adaptador específico de ContainerReplica.
- Não há validação real no DST, multiplayer ou servidor dedicado nesta evidência.
- Os testes/CI existentes são L0-L3 (estático, unitário, contratos e harness); não equivalem a L4/L5.

## 9. Próximas tarefas prioritárias

1. Auditar o caminho completo botão/chat → parser → objetivo → plano → Master → Virtual Player → verificador → relatório.
2. Garantir botão de parar/cancelar, timeout global, idempotência e recuperação de sessão.
3. Criar parser de intenções offline com gramática explícita e testes de ambiguidades/negação/idioma pt-BR.
4. Introduzir um registro de capacidades: ação suportada, lado (client/Master), pré-condições, efeitos, verificador e nível de validação.
5. Implementar staging descartável e perfis isolados antes de liberar ações com efeitos.
6. Criar adaptadores e suites para mods populares somente com fontes verificáveis, licença/API e pós-condições comprováveis.
7. Construir correlação de logs/crashes e minimização de conjuntos de mods suspeitos, sem alegar causalidade sem evidência.
8. Rodar CI no HEAD exato e registrar resultados.
9. Só depois realizar L4/L5 no laboratório; não solicitar testes manuais ao usuário antes do gate 5.0.

## 10. Proveniência e licenças

Nenhum código, arte ou asset de terceiros foi copiado nesta pesquisa. Artificial Wilson foi tratado como referência conceitual por licença não identificada; FAtiMA-DST e Dev Tools têm licença MIT declarada, mas não houve incorporação de código. Reutilização futura exige verificar a licença no arquivo/release específico, preservar avisos e atribuição e respeitar os termos do autor e da Klei.

## 11. Critério de conclusão

Não declarar IA completa até demonstrar:
- Comando por botão e chat interpretado corretamente.
- Planejamento de múltiplas etapas com memória e replanejamento.
- Execução de várias famílias de ações reais, cada uma com verificação independente.
- Diagnóstico com evidências e confiança calibrada.
- Staging seguro, cancelamento, timeouts e recuperação.
- Compatibilidade de cliente, Master, multiplayer e dedicated server.
- Testes de carga/desempenho e regressão em combinações reais de mods.
- Relatórios reproduzíveis e persistência de resultados.
- Validação L4/L5 documentada, não apenas mocks/CI.

**Conclusão:** o caminho mais viável é ampliar o cérebro simbólico existente e conectar de forma segura o Virtual Player a um catálogo crescente de capacidades verificáveis. O agente pode ser autônomo para tarefas de teste delimitadas, offline e sem serviços externos; não deve ser descrito como um ChatGPT local de propósito geral.


## 12. Implementação inicial de comandos por chat — 25/11/2026

- Criado `scripts/modxpector/chat_commands.lua`, parser offline com limite de 256 caracteres e identificadores estritos.
- Comandos reconhecidos: `/mx analisar`, `/mx status`, `/mx ajuda`, `/mx parar`, `/mx testar` (lista suites) e `/mx testar <suite_id> <scenario_id>`.
- O listener usa `ChatHistory:AddChatHistoryListener` no cliente e filtra mensagens do próprio jogador (`sender_userid`) e do tipo de mensagem normal. Mensagens comuns não são interceptadas.
- Respostas são locais via `ChatHistory:OnSystemMessage`; o comando de teste passa pelo mesmo caminho de validação local/Master já existente e continua sujeito a `test_mode`, allowlists e permissões.
- `/mx parar` solicita cancelamento do Virtual Player ou limpa um plano pendente, quando houver.
- Texto arbitrário, IDs inseguros, comandos desconhecidos e payloads semelhantes a código são rejeitados; nenhum texto é executado como Lua.
- Criado teste unitário do parser e incluído no runner Lua 5.1.
- Commit de integração: `07ee488e386d803372041f349cc35c72eb1ab47b`.
- GitHub Actions run `45652447734`: **success**; parse de todos os arquivos Lua, contratos Lua 5.1 e verificação de segurança do pacote passaram.
- Isso comprova parse/contratos do parser e integração estática, não prova que `ChatHistory` esteja disponível no momento de registro em todos os contextos, nem valida chat em sessão real, multiplayer ou servidor dedicado. Essas validações continuam pendentes.
