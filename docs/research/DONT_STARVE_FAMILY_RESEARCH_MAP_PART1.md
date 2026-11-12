# Mapa de pesquisa e atualização — Parte 1
## Família Don't Starve: mecânicas, sistemas e referências técnicas

**Projeto de destino:** Metals and More Reforged  
**Escopo:** organizar a pesquisa da família Don't Starve sem misturar implementações, APIs ou presumir compatibilidade entre jogos.  
**Estado:** levantamento inicial corrigido; inspeção de sistemas específicos continua em andamento.  
**Regra principal:** Don't Starve Together (DST) é a única referência técnica direta para qualquer implementação neste mod.

## 1. Regras de separação e proveniência

| Origem | Uso permitido | Uso proibido |
|---|---|---|
| Don't Starve (DS) base | Ideias de mecânica, balanceamento, itens e lore, identificadas como DS | Tratar seu código/API como DST |
| Reign of Giants (RoG) | Comparação de mecânicas, criaturas, clima, mundo e progressão | Importar scripts ou assumir equivalência de componentes |
| Shipwrecked (SW) | Comparação de exploração marítima, biomas, recursos, clima e sobrevivência | Tratar sistemas de barcos/ilhas como existentes no DST |
| Hamlet (HAM) | Comparação de cidades, comércio, estruturas, recursos e progressão | Presumir que sistemas exclusivos de Hamlet existem no DST |
| Don't Starve Together (DST) | Fonte técnica primária: scripts da versão alvo, componentes, prefabs, replicas, eventos, netvars e testes | — |

Cada registro futuro deve conter: **jogo/origem**, **versão/build**, **mecânica**, **arquivos/funções observados**, **comportamento confirmado**, **diferenças para DST**, **possível adaptação**, **riscos**, **teste necessário** e **status**.

Status permitidos:
- **Confirmado no código DST:** observado nos scripts da versão alvo.
- **Confirmado em documentação:** documentado por referência identificada, ainda sujeito à conferência nos scripts da versão instalada.
- **Observado em outro jogo:** válido apenas para a origem indicada.
- **Hipótese:** interpretação ainda não demonstrada.
- **Proposta:** ideia de design, não aprovada nem implementada.
- **Testado em harness:** teste isolado com stubs; não equivale a teste no jogo.
- **Testado in-game:** reproduzido na versão alvo do DST.

## 2. Correções do levantamento anterior

1. A lista anterior de nomes de componentes e funções era um índice de pesquisa, não uma validação de API.
2. Builder, Prototyper, Container e Workable são nomes relevantes para investigar, mas cada uso precisa ser confirmado nos scripts DST atuais e no contexto servidor/cliente.
3. DeconstructRecipe e MakeForgeRepairable **não ficam confirmados por esta pesquisa**. Não os usar nem documentar como APIs existentes sem localizar a definição real na versão alvo.
4. Uma página de documentação de API não substitui os scripts instalados. Documentação pode estar desatualizada ou refletir outro build.
5. Nenhuma mecânica de DS/RoG/SW/HAM será portada diretamente. Primeiro se descreve a mecânica na origem; depois se procura um equivalente DST; só então se projeta uma adaptação nativa.
6. Não editar código de DS, RoG, SW, HAM, Uncompromising Mode, Hydrated/Dehydrated, Better Lucy ou outros mods. A compatibilidade deve ser implementada do lado do Metals and More Reforged.

## 3. Trilhas de pesquisa da Parte 1

### A. Mundo, biomas e geração
Investigar separadamente por jogo: geração de mundo, biomas, set pieces, estruturas, recursos renováveis, fontes de minério e regras de spawn.  
**Aplicação possível:** avaliar fontes metalúrgicas coerentes e oportunidades de expansão sem criar farms excessivas.  
**Risco:** worldgen e distribuição de recursos variam entre jogos e podem depender de scripts nativos não compartilhados.  
**Estado:** catálogo de tópicos; equivalentes DST específicos ainda precisam de inspeção na versão instalada.

### B. Sobrevivência, clima e ambiente
Comparar estações, temperatura, chuva, umidade, fogo, combustível, luz, sanidade e perigos ambientais.  
**Aplicação possível:** custos de operação, aquecimento e restrições ambientais de forjas/máquinas, somente se fizerem sentido no balanceamento DST.  
**Estado:** pendente de inspeção de componentes e prefabs DST por mecânica.

### C. Itens, fabricação e progressão
Investigar receitas, ingredientes, tags, tech trees, prototipadores, estações, inventários, custos, desbloqueios e fabricação a partir de contêineres.  
**Referência DST confirmada em documentação:** Builder administra receitas, árvores tecnológicas, estações próximas, validação/consumo de ingredientes e sincronização com a réplica do cliente. A documentação consultada lista dependências como prototyper, craftingstation, container e inventory.  
**Implicação para o mod:** bancada/forja devem respeitar a progressão e a autoridade do servidor; não criar receitas remotas ou custos gratuitos. Conferir as assinaturas e o fluxo real no script DST instalado antes de codificar.  
**Estado:** documentação consultada; inspeção integral da versão local ainda pendente.

### D. Forjas, máquinas, combustível e processamento
Catalogar cada sistema por origem: estações, estados de operação, fontes de calor, combustível, tempos, filas/lotes, outputs, interrupções, reparos, save/load e multiplayer.  
**Aplicação possível:** evolução da forja metalúrgica, automação e máquinas industriais do mod.  
**Regra:** separar comportamento de gameplay de detalhes visuais; não inferir que uma forja de outro jogo usa os mesmos componentes do DST.  
**Estado:** prioridade alta; ainda não há confirmação completa dos sistemas vanilla relevantes.

### E. Mineração, drops e economia de recursos
Comparar rochas, minérios, nós, criaturas, loot tables, probabilidades, regeneração e fontes renováveis.  
**Aplicação possível:** ampliar fontes de metais mantendo raridade, risco, custos e compatibilidade aditiva com outros mods.  
**Regra:** preservar as tabelas e probabilidades originais do mod quando a mudança não estiver explicitamente aprovada; não introduzir loops de farm.  
**Estado:** o código atual do mod já possui auditorias próprias de drops; a pesquisa de referências externas deve permanecer separada dessa validação.

### F. Desmontagem, reparo e durabilidade
Investigar por jogo: ações, ferramentas, componentes de construção/desconstrução, reparo, durabilidade, retornos e regras de perda.  
**Aplicação possível:** desconstrução reversível de materiais metalúrgicos e reparos, sem permitir avanço de progressão ou duplicação.  
**Estado:** DeconstructRecipe e MakeForgeRepairable não confirmados; exigir evidência nos scripts DST antes de qualquer uso. A proposta de desconstrução do mod permanece especificação própria, não uma API vanilla confirmada.

### G. Criaturas, NPCs, comércio e lore
Separar mecânicas de criaturas/NPCs, comércio, facções, diálogos, itens e narrativa por jogo. Distinguir fatos de lore, interpretação e teoria de comunidade.  
**Aplicação possível:** inspiração temática, materiais e identidade do mundo; não usar lore de uma expansão como se fosse conteúdo canônico de DST sem qualificação.  
**Estado:** catálogo inicial; pesquisa aprofundada ainda pendente.

### H. Multiplayer, replicação e persistência (DST prioritário)
Inspecionar ismastersim, componentes e réplicas, netvars, eventos dirty, RPCs, ownership, contêineres, tarefas adiadas, save/load, migração e desconexão.  
**Aplicação obrigatória:** toda retirada/consumo de materiais e toda produção metalúrgica devem ser autoritativos no servidor; cliente recebe apenas estado de apresentação.  
**Estado:** exigência arquitetural estabelecida no plano mestre; cada nova mecânica ainda exige teste específico.

## 4. Primeiro índice de APIs DST — sem extrapolar

| Sistema | Papel documentado/esperado | Confirmação e próximo passo |
|---|---|---|
| Builder | Gerencia receitas, tech tree, estações e construção | Documentação da API consultada; comparar com scripts/components/builder.lua da build instalada |
| Prototyper | Estação de pesquisa/prototipagem | Inspecionar componente, tags e integração com Builder |
| CraftingStation | Restrições/receitas associadas à estação | Inspecionar implementação e relação com Builder |
| Container | Slots, inserção/retirada e integração com crafting | Inspecionar componente e réplica; validar callbacks e autoridade do servidor |
| Inventory | Inventário e consumo/entrega de itens | Inspecionar transações, pilhas e falhas por falta de espaço |
| Workable | Interação de trabalho/ferramentas em entidades | Inspecionar ações, work actions, callbacks e uso real em prefabs |
| DeconstructRecipe | Nome citado no levantamento preliminar | **Não confirmado**; não tratar como API |
| MakeForgeRepairable | Nome citado no levantamento preliminar | **Não confirmado**; não tratar como API |

Os nomes acima são pontos de entrada para inspeção, não uma lista de APIs aprovadas para uso. A fonte final para implementação é o conteúdo de data/databundles/scripts.zip da versão DST instalada/servidor dedicado correspondente à versão alvo.

## 5. Fontes consultadas e limites

- Klei Support — https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together. Referência geral oficial sobre escopo de modding; não fornece contrato completo de API.
- Klei Support — https://support.klei.com/hc/en-us/articles/360029554852-Common-Resolutions-Oxygen-Not-Included-Don-t-Starve-Together-Rotwood-Klei-Shop-more. A página informa que Hamlet foi construído sem DST em mente e que a Klei não tem planos anunciados para trazê-lo ao DST; isso reforça que conteúdo de Hamlet não deve ser presumido compatível.
- DST API Webdocs — https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/builder. Documentação comunitária identificada como baseada no build 722832; útil como índice, mas deve ser comparada aos scripts da versão alvo.
- Repositório comunitário de scripts — https://github.com/taichunmin/dont-starve-together-game-scripts. Cópia comunitária para navegação e comparação; não substitui os scripts da instalação do usuário.
- Klei Forums — https://kleiforums.com/forums/topic/136505-how-to-get-developer-tools/. Discussão aponta data/databundles/scripts.zip como fonte dos scripts; confirmar caminho e build no ambiente real.

**Limitação importante:** não foi localizado, nesta etapa, um pacote dos scripts vanilla DS/RoG/SW/HAM e tampouco foi validada a versão instalada do DST. Portanto, não se declara concluída a inspeção de código desses jogos. O mapa organiza a pesquisa e corrige a metodologia; a confirmação técnica depende dos arquivos correspondentes.


## 5. Inspeção inicial de scripts DST — snapshot comunitário

Foi feita uma inspeção direta dos arquivos Lua disponíveis no espelho comunitário taichunmin/dont-starve-together-game-scripts (branch master). Isso é **evidência de código de um snapshot comunitário**, não prova de correspondência com a build instalada do usuário. SHAs observados:

| Arquivo | Blob SHA | Evidência encontrada |
|---|---|---|
| scripts/components/builder.lua | 665bfadd58bec61762ad240bd3f42ac6bb259e9e | Métodos reais incluem EvaluateTechTrees, UsePrototyper, AddRecipe, RemoveRecipe, UnlockRecipe, GetIngredients, RemoveIngredients, MakeRecipe, DoBuild, HasIngredients e CanBuild (marcado deprecated no próprio arquivo). |
| scripts/components/prototyper.lua | 2a93cb6e48e23f39a9ee5cc7fd06c0c0a354283f | Tag prototyper; TurnOn/TurnOff por doer; GetTechTrees; Activate(doer, recipe), que chama onactivate quando configurado. |
| scripts/components/craftingstation.lua | f389e14127fc77a753896a7384a8b282a7684bc8 | LearnItem, KnowsItem, GetItems, GetRecipes, ForgetItem e persistência OnSave/OnLoad. |
| scripts/components/container.lua | 074c3e65383d033ff939bdfd616826660936e37c | WidgetSetup, itemtestfn, GiveItem, RemoveItem/RemoveItemBySlot, Has, ConsumeByName, GetCraftingIngredient, Open/Close e OnSave/OnLoad. |
| scripts/components/workable.lua | ba21f783aa895c715d953bd3284e4e5785818be4 | SetWorkAction, SetWorkLeft, SetMaxWork, SetOnWorkCallback, SetOnFinishCallback, WorkedBy e persistência OnSave/OnLoad. |
| scripts/components/repairable.lua | e33e540840352f7c7cc6c2b9e565a9c85d8421d7 | SetHealthRepairable, SetWorkRepairable, SetFiniteUsesRepairable, NeedsRepairs e Repair(doer, repair_item). |
| scripts/prefabs/storage_robot.lua | 08093fcff63dae7633803a462e1b9283c2c16b8a | Prefab do robô coletor encontrado; a inspeção do fluxo completo deve incluir storage_robot_common.lua e brain/actions, não apenas o prefab principal. |

### Consequências técnicas confirmadas neste snapshot

- O Builder tem um fluxo explícito para avaliar tech trees e prototipadores; a integração de uma bancada não deve ser reduzida a adicionar uma tag.
- Prototyper mantém uma coleção de usuários/doers ativos e executa callbacks de ativação; não é por si só um sistema genérico de forja/combustível.
- Container oferece operações de inventário e persistência; qualquer automação deve verificar os métodos e callbacks reais e executar consumo no servidor.
- Workable expõe callbacks de trabalho e conclusão e possui persistência condicionada ao estado configurado; não equivale automaticamente a uma API de desmontagem.
- Repairable tem métodos para marcar saúde/usos/trabalho como reparáveis e um método Repair; **não existe evidência aqui de MakeForgeRepairable**.
- A busca por DeconstructRecipe não produziu definição confirmada. Sua existência permanece não comprovada.

Links diretos para os arquivos do snapshot:
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/builder.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/prototyper.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/craftingstation.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/container.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/workable.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/components/repairable.lua
- https://github.com/taichunmin/dont-starve-together-game-scripts/blob/master/scripts/prefabs/storage_robot.lua

**Limite:** não foi identificado o commit/build do espelho como correspondente à versão instalada do usuário. Antes de usar uma assinatura ou comportamento em código de produção, comparar com os scripts extraídos da versão alvo do DST. O arquivo storage_robot_common.lua e o caminho completo de coleta/armazenamento ainda precisam ser examinados.

## 6. Critérios de conclusão da Parte 1

- [x] Separação formal entre DS, RoG, SW, HAM e DST.
- [x] DST definido como única base técnica direta do Metals and More Reforged.
- [x] Categorias de pesquisa e aplicação ao mod organizadas.
- [x] Correções de nomes/APIs não confirmados registradas.
- [x] Fontes e limites de evidência registrados.
- [ ] Inspecionar scripts vanilla da versão alvo do DST e substituir referências documentais por evidências de código quando aplicável.
- [ ] Completar fichas de mecânicas de forjas, máquinas, combustível, mineração, desmontagem, inventários, worldgen, save/load e multiplayer.
- [ ] Fazer a comparação separada DS/RoG/SW/HAM, sem reutilizar APIs entre jogos.
- [ ] Revisar o mapa com evidências e separar descobertas confirmadas de propostas de atualização.

**Conclusão:** a estrutura e as regras da Parte 1 estão corrigidas e documentadas. A Parte 1 ainda não pode ser marcada como tecnicamente concluída enquanto os scripts da versão alvo e as fichas de mecânicas pendentes não forem inspecionados.
