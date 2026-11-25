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
