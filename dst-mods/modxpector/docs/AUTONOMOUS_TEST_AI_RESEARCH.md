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


## 13. Auditoria do Virtual Player e isolamento — 25/11/2026

### O que o código faz hoje

 - virtual_player_client.lua recebe ThePlayer (o personagem real do cliente local), constrói BufferedAction e chama ThePlayer.components.playercontroller:DoAction. Portanto, Virtual Player descreve um controlador automatizado do personagem local; não é um segundo jogador/NPC independente.
 - A documentação do componente PlayerController descreve DoAction(BufferedAction) como caminho nativo que valida a ação e coordena locomotor/RPC cliente-servidor. Isso é preferível a criar jogador falso ou contornar autoridade, mas confirma que movimento e ações afetam o personagem real e o mundo atual.
 - A fonte de chathistory.lua no espelho de scripts DST confirma que AddChatHistoryListener(fn) recebe um objeto chat_message com type, sender_userid e message; OnSystemMessage insere mensagem local. O formato usado pelo listener implementado corresponde ao código consultado. A validação real dentro do jogo continua pendente.

### Lacuna de segurança identificada e correção implementada

 - Antes desta atualização, test_mode + permissão de administrador eram suficientes para aceitar planos com ações que alteram o mundo. Não havia confirmação separada de que o save era um laboratório descartável.
 - Foi adicionada a opção laboratory_mode, com padrão false. O Master rejeita qualquer etapa de ação (inclusive WALKTO), crafting, desbloqueio de receita ou spawn enquanto essa opção estiver desativada. Os RPCs de spawn e desbloqueio também verificam essa opção.
 - O painel agora exibe o estado do modo laboratório. A análise passiva e as suites comunitárias observacionais permanecem disponíveis sem ativá-lo.
 - Limite importante: laboratory_mode é uma confirmação explícita do administrador, não um detector infalível de save descartável. Ainda é obrigatório criar um mundo/cluster separado e ativar essa opção somente nele.

### Como separar o laboratório

A documentação oficial da Klei descreve -cluster como seleção da pasta de cluster e -conf_dir/-persistent_storage_root como separação do diretório de configuração/armazenamento. Um cluster separado cria outro conjunto de saves; Master e Caves dentro do mesmo cluster são shards do mesmo mundo e não devem ser confundidos com isolamento. Fonte: https://support.klei.com/hc/en-us/articles/360029556192-Dedicated-Server-Command-Line-Options-Guide.

### Próxima validação

 - Executar os contratos Lua 5.1 e confirmar rejeição do Master com laboratory_mode=false e aceitação controlada com laboratory_mode=true.
 - Fazer teste real apenas em mundo descartável, começando com WALKTO; só depois validar cada ação mutável isoladamente.
 - Verificar lifecycle do listener de chat em reconexão/respawn, RPC e cancelamento no jogo real.
 - Não declarar isolamento físico automático: o mod não cria um segundo mundo em memória.


## 14. Cancelamento real do Virtual Player — 25/11/2026

### Lacuna encontrada

O método Stop() anterior encerrava o executor e o polling, mas não removia a BufferedAction que já havia sido entregue ao personagem. Em caso de timeout/cancelamento, o personagem poderia continuar tentando executar a ação mesmo com o relatório indicando que o Virtual Player parou.

### Contrato do runtime consultado

- EntityScript:GetBufferedAction() retorna primeiro a bufferedaction da entidade e, se ausente, a bufferedaction do LocoMotor.
- EntityScript:ClearBufferedAction() chama Fail() na ação da entidade e a remove.
- LocoMotor:Stop() interrompe movimento e destino, mas a implementação consultada não limpa bufferedaction (a chamada SetBufferedAction(nil) está comentada).
- LocoMotor:Clear() limpa destino e flags e chama SetBufferedAction(nil), removendo a ação do locomotor.
Fontes de código consultadas: [entityscript.lua](https://github.com/vietnd69/dst-scripts/blob/hotfix-714014/entityscript.lua) e [locomotor.lua](https://raw.githubusercontent.com/vietnd69/dst-scripts/hotfix-714014/components/locomotor.lua). Referência comunitária complementar: [Klei Forums — Cancel/stop current action](https://kleiforums.com/forums/topic/143403-cancelstop-current-action/).

### Correção aplicada

- Ao encerrar uma execução com falha, timeout ou Stop(), o Virtual Player consulta a ação atual e só tenta cancelar se ela ainda for exatamente a ação que ele iniciou.
- Se a ação estiver no LocoMotor, usa Stop() e Clear(); se estiver no buffer da entidade, usa ClearBufferedAction().
- Se outra ação substituiu a ação do Virtual Player, não a interrompe.
- O relatório agora expõe active_action_cancellation: cancelled, not_cancelled, error ou not_needed.
- Foram adicionados contratos para ação no locomotor, ação no EntityScript e proteção contra cancelar uma ação alheia.

### Estado de validação

A alteração e os testes foram gravados na branch do PR #76. O GitHub Actions run 45658012911, no commit dd0fa62591e2ce545bfb137d8aa0aaf881d9a9bc (HEAD então atual), passou: parse de todos os arquivos Lua 5.1, contratos completos e verificação do pacote. O log confirma os contratos de cancelamento do Virtual Player, bootstrap do Master e segurança. Isso valida os contratos/harness, não substitui teste real no DST.


## 15. Política final de isolamento para movimento — 25/11/2026

O Virtual Player usa o personagem real local. Por isso, WALKTO não é uma operação de observação: muda a posição do jogador e pode expô-lo a perigos do mundo. A classificação foi endurecida para exigir laboratory_mode para qualquer etapa kind=action, inclusive WALKTO. Somente inspeções/asserções sem movimento ou efeitos podem ser realizadas fora do laboratório.

Foi adicionado um contrato no bootstrap do Master que envia um plano WALKTO com laboratory_mode=false e exige rejeição. As suites comunitárias continuam limitadas a WALKTO, mas agora só podem ser executadas em mundo/cluster descartável com o modo laboratório ativado.


## 16. Autorização de RPC por etapa declarada — 25/11/2026

### Lacuna encontrada

Os RPCs de spawn e desbloqueio de receitas verificavam modo de teste, administrador e allowlists, mas não exigiam que a operação fosse uma etapa do plano atualmente aprovado pelo Master. Isso deixava uma lacuna entre o plano e a autorização efetiva do efeito.

### Correção

- O cliente agora envia request_id, índice 1-based da etapa e run_id nos RPCs de spawn e unlock_recipe.
- O Master exige plano ativo aprovado, run_id correspondente, índice válido, etapa do tipo correto e correspondência exata de prefab/receita e quantidade.
- Cada etapa de efeito pode ser consumida uma única vez. Replays, run IDs antigos, etapas de outro tipo e chamadas depois de limpar o plano são rejeitados.
- O Master cria a tabela de consumo após validar o plano; dados enviados pelo cliente não controlam esse estado.
- A verificação continua combinada com administrador, test_mode, laboratory_mode, allowlists e limites de taxa/quantidade.

### Contratos adicionados

O bootstrap cobre aprovação do plano, bloqueio sem laboratório, execução da etapa autorizada, rate limit, limite de quantidade, falha de entrega ao inventário, run_id incorreto, índice de etapa com tipo errado, replay e chamada após clear_test_plan. O GitHub Actions run 45658012911 no commit dd0fa62591e2ce545bfb137d8aa0aaf881d9a9bc passou com todos os contratos Lua 5.1 e a verificação do pacote.



## 17. Ciclo de vida do listener de chat — 25/11/2026

A fonte chathistory.lua confirma os métodos AddChatHistoryListener(fn) e RemoveChatHistoryListener(fn); os callbacks ficam registrados no manager. A implementação foi ajustada para:

- Resolver ThePlayer no momento em que a mensagem chega, em vez de capturar a entidade antiga na closure.
- Não duplicar o callback quando o mesmo ChatHistory manager persiste após reconexão.
- Remover o callback do manager anterior quando DST substitui o ChatHistory manager e registrar no novo.
- Continuar ignorando mensagens de sistema, evitando loop quando o ModXpector responde no próprio chat.

O bootstrap agora testa comando /mx status, reconexão com troca da entidade ThePlayer e substituição do manager. Esses contratos passaram no run 45658012911. A validação em sessão real, multiplayer e dedicated server continua pendente.


## 18. Recuperação limitada de WALKTO — 25/11/2026

### Pesquisa de runtime

O código de LocoMotor mostra que GoToEntity/GoToPoint definem destino e BufferedAction; FindPath submete uma busca ao TheWorld.Pathfinder. ResetPath mata a busca/caminho atual. FindPath evita buscas repetidas quando lastdesttile é igual ao destino anterior, portanto a implementação limpa lastdesttile antes de chamar FindPath novamente. Fonte: [locomotor.lua (DST script mirror)](https://raw.githubusercontent.com/vietnd69/dst-scripts/hotfix-714014/components/locomotor.lua).

### Implementação

- A recuperação é aplicada apenas a WALKTO, e somente quando a ação ativa continua sendo a mesma BufferedAction registrada no LocoMotor e há um destino válido.
- O executor mede deslocamento do personagem. O padrão é 6 segundos sem progresso para detectar bloqueio.
- Faz no máximo uma tentativa: ResetPath(), lastdesttile=nil e FindPath(). Isso pede uma nova busca nativa; não prova que a rota foi encontrada.
- Se não houver progresso por mais 6 segundos, registra stuck, encerra e cancela a ação ainda pertencente ao Virtual Player.
- O relatório inclui path_replan_requests e active_action_cancellation. O número conta solicitações de nova busca, não caminhos encontrados.

### Teste

Foi adicionado o contrato MODXPECTOR_VIRTUAL_PLAYER_BOUNDED_PATH_REPLAN_CONTRACT_OK: simula personagem sem movimento, confirma exatamente um ResetPath/FindPath, esgota a tentativa e verifica cancelamento da BufferedAction. O novo commit de código ainda aguarda CI; a validação em jogo real permanece pendente.


## 19. Limite espacial para RPCs de spawn — 25/11/2026

A autorização por etapa agora também limita a posição: quando a etapa declara step.position, as coordenadas do RPC precisam ficar a até 4 unidades desse ponto; sem posição explícita, o Master compara com a posição autoritativa atual do jogador e aplica o mesmo raio. Coordenadas não numéricas/NaN/infinito são rejeitadas antes de operações matemáticas. A etapa só é consumida depois de validar tipo, run_id, índice, prefab, quantidade e posição.

O bootstrap inclui uma tentativa de spawn a 100,100 quando o jogador está em 0,0 e exige rejeição sem consumo da etapa. A nova alteração ainda aguarda CI; não considerar o contrato aprovado até a execução correspondente.


## 20. Resposta de chat pelo tipo correto do DST — 25/11/2026

A auditoria de chathistory.lua confirmou SendCommandResponse(messages), que aceita string ou lista e grava mensagens como ChatTypes.CommandResponse. O ModXpector agora prefere esse método e usa OnSystemMessage apenas como fallback se a API não existir/falhar. O listener continua filtrando ChatTypes.Message, evitando responder a si mesmo.


## Checkpoint operacional — 25/11/2026

- PR de desenvolvimento: [#76](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/pull/76), branch `security/modxpector-5.0.14-opt-in-2026-11-23`, HEAD `4e8d112502892ec01e8da4ed178e6391ca22f6a9`, draft/open, sem merge.
- PR de documentação: [#177](https://github.com/andrewrodrigo2003-create/cerebro-secundario/pull/177), branch `research/modxpector-autonomous-ai-2026-11-25`, draft/open, sem merge.
- Implementado neste ciclo: isolamento `laboratory_mode` para toda ação inclusive WALKTO; cancelamento verificado da BufferedAction; autorização de spawn/unlock por run_id + step_index consumível uma vez; limite espacial do spawn; replanejamento nativo limitado para WALKTO; listener ChatHistory resiliente a reconexão/substituição de manager e resposta via SendCommandResponse.
- Testes novos/adaptados: cancelamento e proteção contra ação alheia; rejeição de WALKTO fora do laboratório; ChatHistory com reconexão e manager substituído; RPC com run_id/índice/tipo/consumo único/posição; recuperação de WALKTO limitada.
- Último CI confirmado: [run 45658012911](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45658012911), sucesso no commit `dd0fa62591e2ce545bfb137d8aa0aaf881d9a9bc`. Ele é anterior às alterações posteriores de autorização por etapa, posição e replanejamento. Não atribuir esse sucesso ao HEAD atual.
- HEAD atual ainda precisa de CI. O workflow [ModXpector Package](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/workflows/modxpector-package.yml) tem `workflow_dispatch` para execução manual; esta sessão não dispõe de ação de dispatch.
- Nenhum teste real no DST, multiplayer ou dedicated server foi realizado. Não declarar IA completa.
- Próximo passo técnico: executar o workflow manual ou obter CI no HEAD atual; corrigir qualquer falha antes de ampliar as famílias de ações do Virtual Player. Depois, validar em mundo descartável dentro do jogo.


## 21. Interpretação de linguagem natural offline — pesquisa — 25/11/2026

### Evidências externas

- O projeto [PocketSphinx/JSGF para controle em português](https://hackaday.io/project/34317/instructions) demonstra comandos PT-BR por gramática contextual restrita, com vocabulário e frases previstos; a gramática reduz o espaço de interpretação e evita depender de um modelo de linguagem grande em execução.
- A documentação [Nuance — robust parsing grammars](https://docs.nuance.com/speech-suite/nr-gram/nrg_nlg_robust_parsing.html) descreve extração flexível de conceitos/slots, tolerância a palavras de preenchimento e confiança por slot. Porém, depende de um modelo estatístico de linguagem, então serve como referência conceitual, não como dependência embarcada.
- O [Snips NLU engine](https://github.com/snipsco/snips-nlu/blob/74b2893c/snips_nlu/nlu_engine/nlu_engine.py) usa primeiro um parser determinístico conservador e só depois um parser probabilístico. Para o ModXpector, a primeira camada é adequada; a segunda fica fora do escopo inicial por custo de modelo, memória e ausência de corpus validado.
- O artigo [Joint Intent Detection and Slot Filling with Rules](https://ceur-ws.org/Vol-2242/paper06.pdf) destaca intenção, extração de slots e uso de histórico recente. O princípio útil é separar intent/slots e usar contexto limitado, sem copiar a arquitetura ML do artigo.
- O manual oficial [Lua 5.1 em português](https://www.lua.org/manual/5.1/pt/manual.html) afirma que a biblioteca string assume codificação de um byte; string.lower deixa outros bytes inalterados. Logo, o ModXpector não deve pressupor normalização Unicode/UTF-8 nativa para acentos.
- Recursos portugueses baseados em [finite-state transducers](https://aclanthology.org/L04-1073.pdf) demonstram que FSTs são compactos e adequados para léxicos e gramáticas, embora uma cadeia NLP completa seja grande demais para o mod.

### Decisão técnica recomendada

Não substituir o parser seguro existente nem chamar isso de LLM. Manter `chat_commands.lua` como dispatcher de sintaxe estrita `/mx` e criar, depois da validação do ciclo atual, um módulo separado de interpretação limitada (`intent_interpreter.lua`):
1. Exigir invocação explícita (prefixo `/mx`, `!mx` ou vocativo `ModXpector`) para não interpretar conversa comum.
2. Normalizar acentos PT-BR por tabela explícita de substituição UTF-8 antes de tokenizar; não depender de `string.lower` para caracteres acentuados.
3. Aplicar gramática determinística e léxicos de sinônimos para intents suportadas (status, analisar, testar, parar, ajuda, relatório).
4. Extrair slots fechados (família de mod, suite, cenário, prefab) apenas de allowlists conhecidas.
5. Calcular score/confiança por intent e por slot; se score baixo, slots ausentes ou intents empatadas, perguntar/explicar em vez de executar.
6. Usar contexto de uma interação anterior apenas para resolver follow-ups simples, com expiração e sem ampliar permissões.
7. Separar interpretação da execução: o intent gera estrutura; o planejador valida permissões, laboratório, plano e oráculos antes de agir.

### Limites

Isso permite linguagem natural limitada e segura, não conversa geral como ChatGPT. O parser atual ainda reconhece apenas comandos prefixados e não deve ser anunciado como NLU completo. Implementação adiada até obter CI no HEAD atual e consolidar os contratos do Virtual Player/RPC.


## 22. Resultado da CI e correção do contrato de replanejamento — 25/11/2026

O run [45659771990](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45659771990), no commit `b08ab077dbe5317a2041f37bc2b4328f260274b2`, concluiu parse Lua 5.1 com sucesso, mas falhou na suíte `test_modxpector_virtual_player_live.lua` na linha 915: `expected a scheduled Virtual Player poll`. Os contratos anteriores (bootstrap, configuração, cancelamento, etc.) passaram até esse ponto.

Causa identificada no teste novo: o `VirtualPlayer.new` do cenário de recuperação não recebeu `allowed_actions = { "WALKTO" }`; `BuildAction` rejeitou a ação antes de agendar o poll. Correção aplicada no commit `5ac39b2e341fa3c833409e9e4310ccf62c8dd1f6`, adicionando a allowlist ao cenário. A correção é coerente com o contrato do Virtual Player, mas ainda não foi reexecutada em CI; não marcar como aprovada até novo run.


## 23. CI verde após isolamento do teste WALKTO — 25/11/2026

A segunda falha também era do ambiente de teste, não do executor: contratos anteriores deixavam `TheSim.FindEntities` retornando lista vazia. O cenário de recuperação agora injeta um `path_target` próprio, executa a sequência de polls e restaura a função original ao final (commit `e75dadc8043b7a274a2f2807cb8ed107bc4950c6`).

CI [run 45663743437](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45663743437) concluiu com sucesso no commit `e75dadc8043b7a274a2f2807cb8ed107bc4950c6`: parse Lua 5.1, todos os contratos Lua do ModXpector e verificação de que o pacote não inclui credenciais locais. O contrato `MODXPECTOR_VIRTUAL_PLAYER_BOUNDED_PATH_REPLAN_CONTRACT_OK` passou, confirmando uma única solicitação de ResetPath/FindPath e cancelamento após a segunda janela sem progresso.

Escopo da evidência: validação automatizada em harness Lua 5.1. Não prova comportamento real do locomotor no jogo, compatibilidade multiplayer ou dedicated server; teste in-game ainda pendente.


## 24. Auditoria das APIs nativas de navegação — 25/11/2026

A consulta ao espelho de scripts DST `vietnd69/dst-scripts` (arquivo [`components/locomotor.lua`](https://raw.githubusercontent.com/vietnd69/dst-scripts/main/components/locomotor.lua)) confirma que `ResetPath()` chama `KillPathSearch()` e limpa `self.path`; `Stop()` também limpa `lastdesttile`; `GoToEntity`/`GoToPoint` invocam `FindPath()` e `SetBufferedAction()` mantém a ação no locomotor. O código `entityscript.lua` do espelho `taichunmin/dont-starve-together-game-scripts` confirma que `GetBufferedAction()` retorna `self.bufferedaction` ou, como fallback, `components.locomotor.bufferedaction` ([fonte](https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/entityscript.lua)).

Isso sustenta a estratégia atual: verificar a mesma BufferedAction no Entity/Locomotor, validar `dest`, cancelar a busca anterior com ResetPath, limpar `lastdesttile` e solicitar FindPath. O espelho de scripts é uma fonte comunitária extraída, não um repositório oficial da Klei; a confirmação final exige teste in-game. O contrato foi ampliado no commit `c8d81641c4be3b50fa3e5c812816c264a635858c` para exigir que `lastdesttile` seja limpo antes da nova busca.


## 25. CI verde com contrato do cache de destino — 25/11/2026

O teste WALKTO agora também inicia com `lastdesttile = "stale_destination_tile"` e exige que o replanejamento limpe o cache antes de chamar `FindPath` (commit `c8d81641c4be3b50fa3e5c812816c264a635858c`).

CI [run 45664109579](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45664109579) passou integralmente no commit `c8d81641c4be3b50fa3e5c812816c264a635858c`: parse Lua 5.1, contratos completos, `MODXPECTOR_VIRTUAL_PLAYER_BOUNDED_PATH_REPLAN_CONTRACT_OK`, cenários de ataque repetido e verificação de exclusão de credenciais locais. É validação automatizada do harness, não execução in-game.


## 26. Seleção resiliente e determinística de alvos — 25/11/2026

O Virtual Player agora protege a varredura contra entidades que se tornam inválidas durante a enumeração, entidades sem Transform utilizável e coordenadas não finitas. Um candidato problemático é ignorado sem abortar a busca inteira. O raio também volta ao padrão quando recebe valor não finito e continua limitado ao intervalo seguro.

Quando dois candidatos válidos estão à mesma distância, o GUID define o desempate; se não houver GUID utilizável, a ordem original da enumeração é preservada. Isso reduz variação de alvo entre execuções quando o DST fornece identificadores.

O contrato automatizado cobre empate por GUID, entidade cuja chamada IsValid falha, posição não finita e raio NaN. A CI [45666712487](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45666712487) passou no commit `da225811774fd1ac58b8bf23f786e8f115f0d22b`: parse Lua 5.1, contratos e verificação de exclusão de credenciais. A CI [45666700660](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45666700660) também passou: testes Lua, geração do ZIP e upload do artefato de teste.

**Limite:** os testes usam harness/mocks. Não comprovam comportamento dentro do DST, nem multiplayer ou servidor dedicado. O Virtual Player continua exigindo validação in-game em mundo descartável.


## 27. Confirmação pós-condição de cancelamento — 25/11/2026

A auditoria identificou que `_cancel_active_action` podia interpretar uma chamada de limpeza sem erro como cancelamento confirmado. Isso era insuficiente: uma API pode retornar normalmente sem remover o BufferedAction.

A função agora verifica o estado depois da tentativa de cancelamento. Só retorna sucesso quando `GetBufferedAction()`, `player.bufferedaction` e `locomotor.bufferedaction` não apontam mais para a ação que o ModXpector possuía. Se a ação continuar presente, o relatório registra `not_cancelled`. A proteção contra cancelamento de ações substitutas de outros sistemas foi mantida.

Foi adicionado um contrato negativo em que `Clear()` retorna normalmente, mas deliberadamente não limpa `locomotor.bufferedaction`; o relatório deve permanecer `not_cancelled`.

Validação no HEAD `4184874e1026083073743d9a3d9f7407385b7d56`:
- [Lua 5.1, contratos e verificação de credenciais — run 45671901760](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45671901760): sucesso.
- [Suíte Lua, ZIP e upload de artefato — run 45671890553](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45671890553): sucesso.

**Limite:** harness e mocks não comprovam cancelamento dentro do DST real. Ainda exige validação em mundo descartável e cenários multiplayer/dedicado.


## 28. Revalidação de entidades capturadas nas pós-condições — 25/11/2026

A auditoria das asserções identificou que referências de entidade capturadas por uma ação podiam ser consultadas depois de a entidade ter sido removida. Agora existe `_is_valid_target`, que exige `IsValid()` disponível e retorno verdadeiro, protegendo as asserções `target_exists`, `target_health_lte`, `target_dead`, `target_has_tag` e `player_near_target`.

Entidades capturadas inválidas não podem satisfazer asserções de existência, proximidade ou tags. A asserção de saúde rejeita referência inválida. A morte continua inconclusiva se a entidade desapareceu sem confirmação. Importante: evento `death` previamente registrado continua sendo evidência autoritativa mesmo depois de a entidade deixar de ser válida; a ordem de checagem preserva esse evento.

Contratos adicionados para entidade capturada removida e para evento de morte seguido de remoção.

Validação final no HEAD `a941a2510e760032843aaa4743f1860815fa29ec`:
- [Lua 5.1, contratos e segurança — run 45672485678](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45672485678): sucesso.
- [Testes Lua, ZIP e artefato — run 45672481059](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45672481059): sucesso.

Os commits intermediários `af5f452` e `8ff6d8b` não são a validação final: o primeiro falhou porque a verificação de validade precedia a evidência do evento de morte. A correção reordenou as verificações, e o HEAD final acima passou nos dois fluxos.

**Limite:** testes com harness/mocks; não houve validação dentro do DST real.


## 29. Validação de proximidade do Virtual Player — 25/11/2026

A asserção `player_near_target` agora valida o raio antes de procurar o alvo: deve ser finito e estar entre 0 e 40. Coordenadas inválidas ou não finitas não podem produzir uma aprovação negativa; o resultado fica inconclusivo. A API de Transform ausente é tratada como erro de verificação, não como distância zero.

Os testes cobrem raio negativo, acima do limite, NaN e coordenadas não finitas. A primeira versão do teste usava o seletor de alvo e revelou que `ResolveTarget` normaliza o raio de busca separadamente; o contrato foi corrigido para referenciar um alvo previamente capturado, isolando a propriedade que a asserção deve validar.

HEAD final: `c4fbb873a21cf468cbb1d90bde078849b5491080`.
- [CI Lua 5.1, contratos e exclusão de credenciais — 45673470169](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45673470169): sucesso.
- [CI testes, ZIP e upload do artefato — 45673459863](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45673459863): sucesso.

Os commits intermediários `dbb0548` e `450e6cc` tiveram falha de contrato; a correção final passou nos dois fluxos. A validação continua sendo automatizada por harness, sem execução dentro do DST real.


## 30. Inventário e contêineres abertos — 25/11/2026

A contagem de itens do Virtual Player agora revalida cada entidade presente em `GetOpenContainers()` antes de consultar sua réplica de inventário. Referências de contêiner removidas são ignoradas, evitando contagem fantasma de itens após despawn/remoção. Se a referência não oferece API `IsValid`, a verificação falha de forma fechada em vez de confiar no conteúdo.

Foi adicionado teste em que um contêiner inválido expõe uma réplica falsa com 99 itens; a contagem correta permanece zero.

HEAD atual de código/testes: `626e6881482c7e1d4463d5f2df0a2c694926b3ac`.
- [CI Lua 5.1, contratos e exclusão de credenciais — 45673786778](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45673786778): sucesso.
- [CI testes, ZIP e artefato — 45673779970](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45673779970): ainda em execução na última consulta; não declarar concluído até obter o resultado final.
- O commit de código anterior `873ca82` passou no pacote [45673772572](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45673772572), mas o teste adicional está no commit seguinte e aguarda a execução do pacote.

Sem teste in-game; mocks não substituem validação no DST real.


## 31. Alvo de contêiner capturado removido — 25/11/2026

A asserção `container_has_item` agora exige que o alvo resolvido continue válido (`IsValid() == true`) antes de acessar `replica.container`. Isso cobre referências capturadas por `target_step` que foram removidas entre a ação e a pós-condição. Sem essa guarda, uma réplica residual poderia responder que o contêiner removido ainda contém itens.

Teste de regressão: alvo capturado inválido com réplica falsa que afirma conter 99 unidades; a asserção deve falhar antes de consultar a réplica.

HEAD: `3545e2fc26249a79563259b60feb0e81e0a8bba0`.
- [CI Lua 5.1, parse, contratos e exclusão de credenciais — 45674510077](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45674510077): sucesso.
- [CI testes, ZIP e artefato — 45674502369](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45674502369): em execução na última consulta; não declarar aprovado ainda.
- [Pacote do commit anterior 8eecc02 — 45674493553](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45674493553): verificar separadamente; não inclui o teste final no HEAD 3545e2f.

Sem teste in-game. A correção impede consulta de réplica stale, mas não prova integração no servidor real.


## Atualização — verificação de ganho real de itens — 25/11/2026

Foi identificada uma possibilidade de falso positivo: uma pós-condição como `player_has_item_count_gte` podia aprovar coleta/fabricação quando o jogador já possuía a quantidade exigida antes da ação. O simples estado final do inventário não demonstra que a ação produziu o efeito.

- Código: `436ea2d1c8b6e4befa2ecb3e999bfa89c49c28b7`.
- Testes de regressão: `e58d955b965a67e9d39c1662c20c044ed130c296`.
- Nova asserção `player_item_count_increased` captura, antes da ação, a contagem do prefab referenciado e exige aumento real após a ação.
- A captura é limitada aos prefabs allowlisted que aparecem em pós-condições futuras vinculadas à etapa.
- Os cenários de fabricação de machado e coleta de capim passaram a exigir aumento, não apenas presença/quantidade final.
- Teste negativo: jogador já possui os itens; ação PICKUP não altera inventário; a verificação deve falhar.
- A alteração foi enviada ao branch do PR #76. A consulta de workflows não retornou execução associada ao novo HEAD; portanto, CI ainda não confirmada. Não declarar os novos contratos aprovados.
- Não houve teste dentro do DST, multiplayer ou servidor dedicado.

PR #76 continua draft/open, sem merge ou publicação. A IA permanece incompleta.


### Correção de status de CI anterior — 25/11/2026
A consulta posterior confirmou que o run [45674502369](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45674502369) concluiu com sucesso no incremento anterior de contêiner stale (`3545e2f`): testes Lua, build do ZIP e upload do artefato. Isso não valida os commits posteriores de baseline de inventário (`436ea2d`/`e58d955`). O run [45674703643](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45674703643) também passou, mas é anterior ao novo baseline.


## Incremento — contagens de inventário fail-closed (25/11/2026)

Auditoria do Virtual Player identificou que `_count_player_prefab` normalizava resultados inválidos de réplicas para zero (`tonumber(...) or 0`). Isso poderia ocultar respostas negativas ou NaN e contaminar as pós-condições de coleta/fabricação.

- Código: `3e1e4a69506034e21064600d80d80e1077b399f5`.
- Testes: `6ce11c9efd5fd184fa5f51ab5e21482db1c83977`.
- Agora a contagem da mochila, dos baús abertos e dos itens equipados precisa ser numérica, finita e não negativa (pilha equipada também precisa ser pelo menos 1); respostas inválidas falham explicitamente.
- Testes negativos adicionados para contagem negativa, NaN e contagem negativa de baú aberto.
- Consulta de workflows para o commit de testes não retornou execução. CI deste incremento permanece pendente.
- A auditoria de STORE/TAKEITEM confirmou que a construção da ação é testada, mas ainda falta prova de transferência real de saída/entrada; esse fluxo permanece próximo alvo.
- Sem validação in-game, multiplayer ou servidor dedicado.


## Auditoria adicional — integridade de contagem em contêineres (25/11/2026)

Foi encontrado um caso que ainda não seguia o padrão fail-closed: a asserção `container_has_item` convertia `nil`, NaN ou contagem inválida em zero por meio de `tonumber(found) or 0`. Isso poderia mascarar uma réplica quebrada como ausência válida de itens.

Correção:
- A leitura de `ContainerReplica:Has` agora exige contagem numérica, finita e não negativa.
- Contagem inválida interrompe a avaliação com erro explícito; não é normalizada para zero.
- Testes negativos adicionados para contagem negativa e NaN.
- Código: `5adfc938454d1c3769590bf498c878b9684c48e5`.
- Testes: `53c28545da3e7ff7b1c0bda6534cdfe990dfe105`.
- CI associada aos commits ainda não foi encontrada na consulta inicial; não declarar o incremento validado até consultar novamente.

### Semântica real das ações de transferência — pesquisa de scripts

Fontes comunitárias consultadas no espelho de scripts DST:
- [actions.lua](https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/actions.lua)
- [inventoryitemholder.lua](https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/components/inventoryitemholder.lua)
- [shelf.lua](https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/components/shelf.lua)
- [Container Replica API](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/container_replica)
- [Inventory Replica API](https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/inventory_replica)

Descobertas:
- `STORE` é uma transferência de item: remove o objeto do dono/inventário com `RemoveFromOwner(target.components.container.acceptsstacks)`, tenta `Container:GiveItem` e, se a inserção falhar, devolve o item ao inventário/active item. Portanto, aprovação exige evidência dos dois lados: redução no inventário carregado e aumento no contêiner-alvo. A contagem agregada mochila + baús abertos não serve como oráculo, pois pode permanecer igual.
- `TAKEITEM` vanilla não é uma retirada genérica de baú. Em `actions.lua`, chama `Shelf:TakeItem` quando o alvo é uma prateleira habilitada, ou `InventoryItemHolder:TakeItem` quando o alvo tem esse componente. Ambos tentam entregar o item ao inventário do jogador; o holder também remove o estado de item guardado. O item pode não ser inferível com segurança apenas pelo prefab do alvo.
- `TAKESINGLEITEM` não apareceu na lista de ações vanilla consultada; sua presença em `ACTIONS` deve ser tratada como extensão/mod action possível, não como capacidade vanilla garantida.
- O teste atual apenas constrói BufferedActions STORE/TAKEITEM/TAKESINGLEITEM. Ainda não executa transferência nem verifica deltas reais. Não habilitar essas ações no perfil comunitário.

Próximo desenho seguro:
1. Para STORE, capturar baseline de contagem carregada do jogador e do contêiner-alvo depois de resolver/revalidar o alvo e imediatamente antes de submeter a ação; exigir delta coerente nos dois lados, com quantidade mínima explícita para aceitar transferência parcial.
2. Para TAKEITEM, suportar inicialmente somente alvos cujo item possa ser identificado por uma API/netvar observável e estável; exigir aumento no inventário carregado e mudança observável do estado do holder/prateleira. Sem item identificável ou réplica disponível, resultado inconclusivo/blocked.
3. Cobrir rollback, baú removido, alvo removido, inventário cheio, transferência parcial, réplica indisponível e contagens inválidas.
4. Não tratar sucesso do retorno da ação como prova de transferência.

A pesquisa usa espelhos comunitários de scripts e documentação de API, não o build instalado da Klei; validar contra os scripts/runtime do jogo e em staging descartável antes de declarar compatibilidade.


### Resultado da CI — contagem fail-closed de contêiner (25/11/2026)
- [ModXpector Lua checks — run 45681303062](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45681303062): **success**, no commit de testes `53c28545da3e7ff7b1c0bda6534cdfe990dfe105`.
- [ModXpector package — run 45681293374](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45681293374): **success**, no mesmo commit de testes.
- [ModXpector package — run 45681288149](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45681288149): **success**, no commit de código `5adfc938454d1c3769590bf498c878b9684c48e5`.
- [ModXpector package após documentação — run 45681331607](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45681331607): **success**, no commit documental `e8d3201577137683438abf8afe221f97aa1b01ad`.
- O resultado valida parse/contratos/pacote automatizados correspondentes aos workflows; não valida execução real dentro do DST.
- PR #76 e PR #177 continuam draft/open e sem merge. Nenhum teste in-game, multiplayer ou dedicated server foi executado.


## Implementação — oráculos de transferência STORE/TAKEITEM (25/11/2026)

### O que foi adicionado
- `player_inventory_item_count_decreased`: exige delta negativo na contagem carregada/equipada do jogador, sem somar baús abertos.
- `player_inventory_item_count_increased`: exige delta positivo na contagem carregada/equipada.
- `container_item_count_increased`: exige delta positivo no contêiner-alvo capturado.
- Os baselines são capturados depois de construir a BufferedAction e resolver/revalidar o alvo, mas antes de chamar `PlayerController:DoAction`.
- O baseline do contêiner exige réplica válida e `ContainerReplica:IsOpenedBy(ThePlayer)`. A fonte consultada mostra que `ContainerReplica:Has` retorna zero quando o contêiner não está aberto/replicado para o jogador; contar um baú fechado como zero poderia criar falso positivo. Contêiner fechado, réplica ausente, alvo removido ou contagem inválida bloqueiam a captura.
- `target_has_tag` e `player_near_target` agora ficam inconclusivos quando o alvo capturado já não é válido; não podem passar uma expectativa negativa só porque a entidade desapareceu.

### Contratos exigidos pelo Master
- STORE precisa de dois oráculos vinculados à mesma etapa: redução do inventário do jogador e aumento do contêiner.
- Os dois oráculos precisam usar o mesmo prefab do `invobject` da ação e a mesma quantidade mínima. Transferências parciais são aceitas quando ambos os lados demonstram o delta mínimo.
- TAKEITEM precisa demonstrar aumento no inventário e remoção do estado de item disponível do alvo, por `takeshelfitem` ou `inventoryitemholder_take`.
- O Master rejeita oráculo de transferência associado a outra etapa, expectativa negativa de delta, STORE com prova de apenas um lado, STORE com prefab divergente e TAKEITEM sem prova independente de mudança no holder/prateleira.
- Isso não libera STORE/TAKEITEM no perfil comunitário atual; a suite pública continua restrita a WALKTO.

### Testes adicionados
- STORE: transferência parcial com deltas coerentes; mudança em apenas um lado; alvo removido; contêiner fechado; réplica ausente; contagem NaN/negativa.
- TAKEITEM: aumento real de inventário e remoção da tag do holder; ausência de alteração não passa.
- Master: pares obrigatórios, prefab correspondente ao invobject, mesma etapa e rejeição de prova incompleta.
- Alvos removidos não podem satisfazer expectativas negativas de tag/proximidade.

### Commits e CI
- Código: `b60d42b88b21ca9f7e5366896576dd046ec7f961`, `188ff44da1170dacb9ed216cfd2dee4208e1594a`, `8a36052e3579d0385b64921b1bc4217553e476cd`, `f48937918908df9fe1a3351e37cb6d035897fec5`, `3a6fbf5ee3f7b1f9a3a5b637ed2afce5db0f4cbb`, `df3f97cb0e64a491d8c867aca3e746f4b5b32255`, `5ebffad0b6237cdd9f3c368e0f4c96c91c6498af`.
- Testes: `160238ab2f8274960cbb4299cf142854e75fd7b0`, `b5774b6c638d20c66ede885e1298f16f74e5d7d6`, `8de2482e90fe571a6835c1298f53315a0bb98881`, `19bb23052eeb25af1ea69d9715cb6d918873a887`, `cd6449fda44cb8eee5cbb817412fb7a128bfa8b2`, `65fc35f9f5f53b488a0f376c7a9da357b6bd3841`, `37e59cf0047025b660b5cf8301c81f8fc90302da`, `a1ab5089d06541558c5142229507b641130e45d2`.
- [Lua checks — run 45682174403](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682174403): **success** no commit de testes `65fc35f`; inclui parse Lua 5.1, contratos e verificação de credenciais do pacote.
- [Package — run 45682134866](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682134866): **success** no commit de código `5ebffad`.
- A validação mais recente dos testes adicionados depois de `65fc35f` ainda precisa terminar no HEAD atual antes de declarar o conjunto final aprovado.
- Nenhuma execução real dentro do DST, multiplayer ou dedicated server foi realizada. Os testes são harness/mocks; não provam que a transferência funciona em sessão real.

### Limites conhecidos
- STORE só é verificável pelo oráculo atual quando a réplica do contêiner está aberta ao jogador e expõe `IsOpenedBy` + `Has`; proxies e recipientes sem réplica compatível falham de forma fechada.
- TAKEITEM só pode ser aprovado quando o prefab do item é explicitamente allowlisted e a suite identifica a tag correta do alvo. Não é retirada genérica de baú.
- `TAKESINGLEITEM` não consta como ação vanilla nas fontes consultadas; tratar apenas como possível extensão de mod, não como ação DST padrão.
- A implementação não executa a ação em ambiente real e não deve ser descrita como transferência já validada in-game.


### Validação final do incremento de transferência — 25/11/2026
- [Lua checks — run 45682243266](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682243266): **success** no commit de testes `a1ab5089d06541558c5142229507b641130e45d2`. Parse Lua 5.1, contratos completos e verificação de exclusão de credenciais passaram.
- [Package — run 45682230818](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682230818): **success** no mesmo commit. Runner Lua passou, ZIP distributável foi construído e artefato enviado.
- [Lua checks — run 45682286656](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682286656): **success** no HEAD documental `0fe820a1ffa8d0e5cc494fe61db0e34d30293c09`.
- [Package — run 45682278811](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682278811): **success** no mesmo HEAD documental.
- Os contratos cobrem os oráculos e as validações do Master via mocks/harness. Não são execução da ação real no DST.
- PR #76 permanece draft/open, sem merge/publicação. PR #177 permanece draft/open, sem merge.
- Não houve teste real no DST, multiplayer ou dedicated server. A IA permanece incompleta e STORE/TAKEITEM não foram liberados no perfil comunitário.


### Auditoria adicional — identidade e transição de estado em TAKEITEM (25/11/2026)

**Resultado: bloqueio encontrado; não liberar TAKEITEM/TAKESINGLEITEM.**

A inspeção do código do PR #76 encontrou uma lacuna real nos oráculos atuais:

1. O plano pode pedir aumento de inventário para qualquer prefab allowlisted, mesmo que esse prefab não seja o item que estava no alvo. O contrato Master de TAKEITEM aceita, por exemplo, alvo `birdcage` + aumento de `cutgrass`.
2. A segunda prova atualmente aceita `target_has_tag expected=false`. Essa asserção verifica somente o estado posterior; não exige que a tag estivesse presente antes da ação. Se o alvo já não tinha a tag antes, a pós-condição pode passar sem que TAKEITEM tenha removido item algum.
3. O teste atual de TAKEITEM cobre tag presente que depois desaparece, mas não cobre a regressão de tag ausente antes e depois, nem vincula o GUID/prefab do item retirado ao item que entrou no inventário.
4. O código vanilla consultado mostra que `ACTIONS.TAKEITEM.fn` chama `shelf:TakeItem(doer)` ou `inventoryitemholder:TakeItem(doer)`; `TAKESINGLEITEM.fn` chama `inventoryitemholder:TakeItem(doer, false)`. Portanto, a ação pode transferir a entidade/stack do alvo e tem semântica diferente de retirar de baú.
5. A prateleira usa a tag `takeshelfitem`; inventoryitemholder usa `inventoryitemholder_take`. O oráculo deve identificar o tipo de alvo e comprovar a transição correspondente.

**Correção exigida antes de habilitar a ação:**
- Capturar, antes de `PlayerController:DoAction`, a identidade verificável do item mantido pelo alvo (GUID + prefab e, quando aplicável, tamanho da pilha), usando somente uma API cliente replicada comprovada.
- Depois da ação, exigir prova de que o mesmo item/entidade foi recebido pelo inventário; contagem agregada por prefab isolada não basta.
- Registrar baseline da tag correta (`inventoryitemholder_take` ou `takeshelfitem`) e exigir transição presente → ausente. Estado ausente antes da ação deve resultar em falha/inconclusivo, nunca em sucesso.
- Cobrir TAKEITEM integral, TAKESINGLEITEM parcial, item já ausente, alvo despawnado, item empilhado/stack parcial, inventário cheio e item que cai no chão.
- Master deve validar que a pós-condição de identidade se refere ao mesmo step e prefab/item declarado.

**Fontes de semântica consultadas:**
- Código vanilla `actions.lua`: TAKEITEM/TAKESINGLEITEM e caminhos de execução — https://github.com/jupitersh/dst-scripts-source-code/blob/master/actions.lua
- `inventoryitemholder.lua`: CanTake, TakeItem, transferência para inventário, pilha parcial e atualização da tag — https://github.com/vietnd69/dst-scripts/blob/main/components/inventoryitemholder.lua
- API/descrição de shelf — https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/shelf
- Mapeamento de ações por tags/componentes — https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/componentactions

**Estado operacional:** o incremento STORE/TAKEITEM anterior continua coberto por CI automatizado, mas isso não valida a correção acima. STORE permanece fora do perfil comunitário; TAKEITEM e TAKESINGLEITEM também permanecem bloqueados. Não houve execução real dentro do DST, multiplayer ou dedicated server.

### CI documental mais recente — 25/11/2026
- Lua checks [45682409667](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45682409667): **success** no HEAD documental `444ea2571aee36cc43a98cf6f6bf1bdcd8463532`.
- O resultado confirma parse Lua 5.1, contratos e verificação de credenciais no commit testado; não cobre a nova lacuna de semântica identificada nesta auditoria.
- PR #76 e PR #177 continuam draft/open, sem merge ou publicação.


### Correção de segurança — bloqueio fail-closed das ações de retirada (25/11/2026)

- O Virtual Player agora interrompe `TAKEITEM` e `TAKESINGLEITEM` antes de construir/enviar a BufferedAction.
- O resultado é `inconclusive`, não `passed`: identidade do item recebido e transição pré/pós da tag ainda não estão comprovadas.
- Teste de regressão executa ambos os nomes de ação com um PlayerController instrumentado e exige zero chamadas a `DoAction`.
- Código: `5a0230bf02e40326b67a8ac14264a3cbab2df0fa`.
- Teste: `70f600567e32d95364d08e204c3444cb1e619dd1`.
- CI do pacote/testes do ModXpector no commit de teste: run [45684407675](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45684407675), ainda em fila na última consulta. Não declarar aprovado até concluir.
- A correção é uma contenção segura, não a implementação final da retirada. STORE também continua fora do perfil comunitário. Nenhuma validação real dentro do DST/multiplayer/dedicated server.


### Resultado final de CI do bloqueio fail-closed — 25/11/2026
- Lua checks [45684416185](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45684416185): **success** no commit de teste `70f600567e32d95364d08e204c3444cb1e619dd1`.
- Package/testes [45684407675](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45684407675): **success** no mesmo commit; suíte Lua, ZIP e upload do artefato concluídos.
- Package documental [45684441954](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45684441954): **success** no commit documental `0ee34f86190f70f9687d2d5ca2e2a3be12541525`.
- A contenção passou nos contratos automatizados. Não é validação in-game.


### Auditoria e contenção de STORE — 25/11/2026

**Achado:** as pós-condições anteriores comparavam somente deltas agregados por prefab. Mesmo com queda da contagem no inventário e aumento da mesma contagem no baú, não se prova que o mesmo item/stack foi transferido. Mudanças simultâneas independentes do mesmo prefab poderiam satisfazer os dois lados. A seleção por prefab em `FindItem` também não preserva uma identidade estável entre o item selecionado e o item recebido pelo contêiner.

**Contenção aplicada:** `STORE` agora é interrompido antes de `PlayerController:DoAction` e reportado como `inconclusive`. Foi adicionado teste de regressão exigindo zero chamadas ao controller. Isso impede que o oráculo antigo produza uma falsa aprovação como se fosse prova de identidade.

- Código: `ed3f8357543da7243234d8138cebe9363a17c16f`.
- Teste: `85f774f61c58958440372218779d9b4de86f6b7c`.
- CI package/testes [45685429266](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45685429266): pendente na última consulta.
- Próxima implementação segura: capturar identidade do item selecionado (GUID/prefab/stack), verificar destino e transferência real; tratar active item, slots equipados, pilhas parciais, inventário cheio, overflow e containers proxy. Não reabilitar com base apenas em contagem agregada.

**Estado:** STORE, TAKEITEM e TAKESINGLEITEM permanecem fail-closed. Nenhuma validação in-game, multiplayer ou dedicated server.


### CI final da contenção STORE — 25/11/2026
- Package/testes [45685429266](https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/45685429266): **success**; suíte Lua, geração do ZIP e upload do artefato concluídos no commit de teste `85f774f61c58958440372218779d9b4de86f6b7c`.
- Package da documentação no commit `2bcfe4ee982219da9365c232437816c548d92298` ainda estava em execução na última consulta.
