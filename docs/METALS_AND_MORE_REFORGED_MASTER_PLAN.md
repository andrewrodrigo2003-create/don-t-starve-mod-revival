# Metals and More Reforged — plano mestre de atualização

**Título original do pedido:** Metals and More – Reworked & Fixed  
**Nome provisório da atualização:** Metals and More Reforged  
**Mod:** `dst-mods/metals_and_reforged`  
**Status geral:** em desenvolvimento. Este documento é a lista mestre; não substitui nem reduz o pedido original.

## Regras que não podem ser quebradas

- Trabalhar exclusivamente no Metals and More.
- Não editar Uncompromising Mode, Hydrated/Dehydrated, Better Lucy, Woodie - Better Skill Tree, APIs ou qualquer outro mod. Compatibilidade deve ser feita do lado do Metals and More.
- Preservar mecânicas, materiais, identidade dos metais, receitas, progressão e custos originais, exceto quando uma mudança estiver explicitamente descrita neste plano e for necessária para corrigir um bug ou cumprir o pedido.
- Não criar farms fáceis, duplicação de drops, consumo gratuito, perda silenciosa de materiais ou atalhos que destruam a progressão.
- Não remover tempo, combustível, custo ou estações necessárias apenas por conveniência. QoL não deve trivializar a metalurgia.
- Não substituir código antigo sem investigar o comportamento e as dependências.
- Manter multiplayer e autoridade do servidor em mente: cliente pode prever/exibir, servidor decide e consome.
- Mudanças independentes devem ficar em branches separadas; verificar PRs/commits antes de editar arquivos compartilhados. Não sobrescrever, force-push, rebase histórico publicado ou fazer merge sem necessidade.
- Diferenciar sempre auditoria estática, teste de módulo real, harness comportamental, teste com APIs do DST e teste dentro do jogo. Nunca declarar compatibilidade integral sem teste real.
- A instalação de teste do usuário é o mundo **“mundo de testes de mod”**. Não presumir acesso ao computador local.
- O nome provisório “Metals and More Reforged” não deve ser alterado sem autorização.

## 1. Proveniência, autoria e direitos de uso

- [~] Criar arte vetorial original para o banner e ícone quadrado, sem reutilizar a arte legada; fontes SVG existem no PR #7, mas PNG exportados e KTEX ainda não foram entregues nem integrados.
- [ ] Converter o ícone quadrado para KTEX e substituir o `modicon.tex` legado somente após validação.
- [ ] Fazer inventário arquivo a arquivo de código, arte, sons, animações, textos e assets herdados.
- [ ] Separar claramente o que veio do rework de NevilleDST, o que veio do mod original de Benzoquinone e o que foi escrito do zero nesta atualização.
- [ ] Confirmar licença/autorizações aplicáveis antes de redistribuir publicamente qualquer código ou asset herdado; se não houver permissão documentada, substituir por implementação independente e assets originais.
- [ ] Preservar créditos corretos no `modinfo.lua`, Workshop e documentação até que a origem/licença de cada parte esteja resolvida.
- [ ] Não afirmar que a troca da capa torna o código herdado original ou impede reclamações.

**Cadeia identificada:** o rework 2.9.3 de NevilleDST declara que deriva de *Metals and More!* de Benzoquinone. As duas páginas de Workshop atualmente exibem aviso de remoção pela Steam; isso não prova que houve reclamação de direitos autorais. Ver `docs/ASSET_PROVENANCE_AND_COVER_ART.md`.
## 2. Restauração e identidade metalúrgica

- [x] Preservar a estrutura existente de minérios, poeiras, fragmentos, lingotes, ligas e materiais especiais no código atual.
- [ ] Comparar todas as receitas, ingredientes, tags, custos, prioridades, tempos, outputs e fontes de materiais com a versão original 2.9.3.
- [ ] Confirmar que cada metal mantém função e progressão próprias; não tornar um metal substituto universal.
- [ ] Auditar todas as receitas para evitar entradas sem custo, requisitos que não são consumidos e itens consumidos mais de uma vez.
- [ ] Revisar os materiais raros e as ligas avançadas sem remover suas etapas de processamento.
- [ ] Registrar qualquer divergência do original e a justificativa da correção.

**Já corrigido na fundição:** fallback de nitre com fragmentos de gemas, consumo do requisito lunar de moonglass, custo mínimo de junk dust e entrega do lote completo ao martelar uma forja pronta. PR #1 foi integrado à main.

## 3. Mineração e fontes de materiais

- [x] Há implementação de drops extras para rochas da superfície/lua, formações de cavernas, criaturas das ruínas, hounds, árvores/arbustos de mármore e tubarão.
- [x] Existe configuração geral e configuração por fonte; o modo aditivo é o padrão para preservar drops de outros mods.
- [x] PR #16 integra a correção de Rewrite originalmente preparada no PR #6 e adiciona harness Lua 5.1 que carrega os módulos reais `loot_guard.lua`, `modded_drops.lua` e `newrocks.lua`; testes in-game/UM Beta ainda pendentes.
- [x] Comparação estática confirmou que as 18 tabelas originais mantêm todos os nomes e pares item/chance.
- [x] Harness LuaTeX isolado da lógica de decisão passou 9 cenários; não executa o módulo completo nem o DST.
- [x] Existe opção para normalizar rolls repetidos, desligada por padrão para preservar as probabilidades originais.
- [ ] Auditar todas as probabilidades e quantidades contra o v2.9.3, incluindo rolagens repetidas e fases de crescimento.
- [ ] Confirmar que cada fonte é coerente com o material e com o risco da criatura/bioma.
- [ ] Verificar que recursos plantados ou renováveis não criam farms de minério não intencionais.
- [ ] Verificar que nenhum item vanilla ou drop de outro mod é removido no modo aditivo.
- [x] Confirmar por harness runtime as gates de Rewrite, com a ressalva de que a substituição de loot tables é comportamento legado e ainda exige validação em mundo real.
- [ ] Testar cada fonte com as opções geral e individuais desligadas/ligadas.

## 4. Forja em lotes e previsão

- [x] Existe cálculo de lote, limite por operação, crescimento de tempo, previsão de produto/quantidade e comunicação do plano do servidor via netvar.
- [x] A previsão lê a netvar por `:value()`, não como função.
- [x] Há simulações documentadas de receitas, consumo e divisão de outputs.
- [ ] Validar todas as receitas e combinações ambíguas com o algoritmo real de consumo.
- [ ] Confirmar limites individuais de cada produto, limite global e arredondamento de pilhas.
- [ ] Confirmar que o tempo de fundição cresce de acordo com a configuração e não reduz custos de combustível.
- [ ] Testar interrupção por dano, martelo, remoção, desconexão, save/load e morte do servidor.
- [ ] Garantir que nenhuma entrada desapareça ou seja duplicada em transições de estado.
- [ ] Verificar previsão idêntica ao resultado autoritativo do servidor em multiplayer.
- [ ] Corrigir e validar a configuração de sobras em todas as rotas de interrupção e colheita.

## 5. Livro metalúrgico

- [ ] Criar/terminar um livro de consulta de metalurgia com receitas, materiais, requisitos, outputs, tempos e etapas.
- [ ] O livro é informativo: não substitui a forja, bancada ou estação necessária.
- [ ] Não conceder desbloqueios, receitas gratuitas ou fabricação remota por consultar o livro.
- [ ] Exibir alternativas e requisitos sem prometer resultado determinístico quando a mistura for ambígua.
- [x] Auditar o craftbook atual: ele é um prototyper portátil e não pode ser reutilizado como livro informativo.
- [x] Pesquisar APIs vanilla `book`/`simplebook`: callbacks de leitura não fornecem catálogo multi-página; a referência precisará de UI própria e somente leitura.
- [~] Documentar arquitetura do livro e pontos em aberto das bancadas em `docs/design/METALLURGY_REFERENCE_BOOK_AND_STATIONS.md`; implementação e validação pendentes.
- [ ] Garantir textos/localização e interface legíveis em PT-BR e inglês, seguindo a estrutura existente.

## 6. Bancadas, fabricação e progressão

- [x] Existe prefab `warworkbench` e uma estação/tab de fabricação de metal no código.
- [x] Existe migração de receitas para o craftbook com proteção para preservar ingredientes de outros mods.
- [~] Inventário inicial encontrou `warworkbench` (prototyper ALCHEMY_ONE), `craftbook` (CRAFTSBOOK_ONE) e aba “The Forge Event”; receitas de armas ainda precisam de matriz de estação/tech e comparação com v2.9.3 antes de mover.
- [ ] Auditar a lista completa de receitas que devem sair da máquina de ciências e ir para a bancada correta.
- [ ] Manter a bancada de armas e criar/terminar a bancada de guerra para equipamentos metálicos, sem duplicar receitas.
- [ ] Garantir que a progressão de tecnologia, materiais e estações continue coerente.
- [ ] Confirmar custos e requisitos originais das receitas e o comportamento com receitas removidas/alteradas por outros mods.
- [ ] Testar construção, colocação, funcionamento, animações, destruição e drops das estações.

## 7. Armazenamento metalúrgico

- [x] Primeiro contêiner dedicado integrado via PR #13 (que incorporou a implementação do PR #5): 25 slots, tags `chest` + `mam_metal_storage`, destruição com martelo devolvendo conteúdo e filtro ligado ao registro real da metalurgia. O filtro aceita ingredientes e produtos registrados (minérios, poeiras, fragmentos, lingotes e ligas). CI completo aprovado; testes in-game/save-load/multiplayer ainda pendentes.
- [x] Harness isolado do prefab passou com LuaTeX: registro, assets, placer, tags, widget, callbacks, hit sem derramar, martelo devolvendo conteúdo e separação servidor/cliente. Não valida o motor DST nem a aceitação real de itens.
- [ ] Criar/validar o contêiner próprio para metais, minérios, poeiras, fragmentos, lingotes, ligas e materiais metalúrgicos definidos pelo mod.
- [ ] Definir filtros explícitos por prefab/tag; não aceitar itens arbitrários nem bloquear materiais legítimos.
- [ ] Preservar inventário ao martelar, fechar, desconectar, salvar e carregar.
- [ ] Garantir que itens não sejam perdidos se a estrutura for destruída ou se um slot não puder aceitar o item.
- [ ] Fazer a integração com containers externos de forma passiva e compatível; nunca editar os outros mods.
- [ ] Priorizar compatibilidade com o armazenamento do Uncompromising Mode Beta, sem presumir APIs internas estáveis.
- [ ] Implementar consulta centralizada opcional apenas para depósitos próximos e acessíveis.
- [ ] Mostrar quantidade e localização; retirada deve respeitar distância, propriedade, permissões, slots e multiplayer.
- [ ] Não permitir acesso global, retirada através de paredes, acesso a depósitos de outros jogadores ou duplicação por corrida de requests.
- [ ] Integrar consulta com fabricação somente se for possível reservar/consumir itens atomicamente no servidor; sem retirada fantasma.
- [ ] Adicionar opções para contêiner, consulta e integração com estações, todas desligáveis e com defaults seguros.

**Estado encontrado na auditoria:** existem `marble_chest` e `cold_safe` como contêineres genéricos do mod. O primeiro baú metalúrgico dedicado foi adicionado em código no PR #5; consulta centralizada e integração com estações continuam sem implementação. As chaves internas `mam_storage_query` e `mam_station_storage` foram removidas em PR #8 até que a consulta/integração exista; não expor essas opções como se funcionassem.

## 8. Configurações

- [x] Existe módulo central `mam/config.lua` e opções para lote, limite, tempo, sobras, previsão, overrides de receitas e drops.
- [ ] Auditar todos os consumidores de cada opção exposta; a validação de valores do módulo central foi concluída em PR #8, mas a auditoria de uso funcional ainda está em aberto.
- [ ] Remover ou não expor opções sem implementação; nunca deixar controles placebo.
- [~] Opção `mam_metalschest` adicionada ao `modinfo.lua` no PR #5 (default on); teste no jogo pendente.
- [ ] Adicionar configurações de armazenamento/consulta somente quando os recursos estiverem implementados.
- [ ] Garantir que defaults preservem a experiência original quando a opção estiver desligada.
- [x] Validar no módulo central os tipos, enums permitidos, limites e fallback para valores ausentes/inválidos; harness direto com 103 verificações em PR #8.
- [~] Validar transmissão real das configurações entre servidor e cliente e mensagens de configuração; overrides foram testados isoladamente, mas host/cliente real continua pendente.
- [ ] Agrupar opções por tema, com explicações claras e consistentes em PT-BR/inglês.

## 9. Compatibilidade com Uncompromising Mode Beta

- [x] Existe proteção de receitas que evita substituir balanceamento de outros mods no modo seguro.
- [x] Drops adicionais têm modo aditivo como padrão; hounds têm opção Auto para ceder ao UM.
- [ ] Auditar todos os pontos de integração: receitas, tags, loot, prefabs, containers, actions, tech trees, UI, física e hooks de jogador.
- [ ] Verificar versões atuais do UM Beta usadas pelo jogador antes de afirmar compatibilidade.
- [ ] Testar receitas e loot lado a lado com UM Beta habilitado, sem editar o código do UM.
- [ ] Testar os principais mods de armazenamento/inventário e APIs do conjunto do usuário.
- [ ] Investigar separadamente a falha de colisão relatada com Woodie; não atribuir causa ao Metals and More sem reprodução.
- [ ] Registrar incompatibilidades confirmadas e soluções implementadas do lado do Metals and More.

## 10. Pesquisa e referências

- [ ] Pesquisar mods de DST e outros jogos com boas soluções de mineração, metalurgia, fabricação, forjas, armazenamento, transporte e interfaces.
- [ ] Registrar fonte, versão, mecânica observada e o que pode ser adaptado.
- [ ] Usar referências como inspiração técnica, sem copiar código/assets protegidos nem alterar a identidade do Metals and More.
- [ ] Comparar soluções com o pedido original e o equilíbrio de Don't Starve Together antes de implementar.

## 11. Testes e qualidade

- [x] Há relatório de simulação da fundição e testes de matriz de receitas/consumo documentados.
- [x] Auditoria de save/load e ciclo de vida no componente real da forja: harness Lua 5.1 com 22/22 assertions aprovadas; validação no motor DST ainda pendente.
- [x] Há relatório estático e harness de prefab para o primeiro baú metalúrgico (PR #5); o harness passa em ambiente com stubs, mas ainda não testa o motor DST.
- [x] Há auditoria de Rewrite e comparação entry-by-entry das 18 loot tables, com harness runtime integrado pelo PR #16.
- [x] Harness isolado da decisão Auto/Always/UM passou 9 cenários; parsing dos arquivos completos e teste real no jogo continuam pendentes.
- [ ] Executar análise sintática de todos os Lua com Lua 5.1/ambiente compatível.
- [ ] Testar carregamento dos módulos e referências a globals/APIs do DST com stubs e/ou scripts do jogo.
- [ ] Testar todas as receitas, estações, itens, estruturas, criaturas e materiais.
- [ ] Testar lote, previsão, custo, combustível, tempo, sobras, colheita e destruição da forja.
- [ ] Testar livro, configurações, drops e armazenamento.
- [ ] Testar save/load, migração de estado, host/cliente, multiplayer e desconexão.
- [ ] Testar com Uncompromising Mode Beta e conjunto de mods do mundo `mundo de testes de mod`.
- [ ] Separar resultados de testes unitários, harness, estáticos e testes reais dentro do jogo.
- [ ] Registrar logs, reprodução, correção, regressão e limitações em relatórios versionados.

## 12. Entrega e documentação

- [ ] Manter este plano mestre atualizado a cada etapa.
- [ ] Manter changelog com mudanças funcionais, correções, opções e compatibilidade.
- [x] Criar arte vetorial original para o banner e ícone do Metals and More Reforged; não reutiliza a arte legada. A conversão do ícone para KTEX ainda está pendente.
- [ ] Entregar relatório final com o que foi restaurado, corrigido, adicionado e testado.
- [ ] Listar limitações conhecidas e testes que ainda dependem do computador/jogo do usuário.
- [ ] Não declarar a atualização pronta enquanto funcionalidades essenciais e testes críticos estiverem pendentes.

## Próxima sequência de execução

1. Concluir auditoria da fundição e da previsão, incluindo ciclo de vida e save/load.
2. Validar em jogo a auditoria de mineração/drops e registrar matriz por fonte/configuração, incluindo UM Beta.
3. Validar craftbook, bancada de guerra e progressão.
4. Projetar e implementar o armazenamento metalúrgico em etapas pequenas, começando pelo contêiner próprio e seus filtros.
5. Implementar consulta próxima somente depois que o armazenamento básico estiver seguro.
6. Completar testes de compatibilidade, multiplayer e mundo de testes.
7. Finalizar documentação, changelog e entrega.

## Histórico de mudanças já integradas

- PR #1 — correções de consumo de nitre/moonglass/junk dust e drops completos do lote ao martelar a forja; integrado em `main` em 2026-11-07.
- PR #5 — sua implementação foi incorporada pelo PR #13 e o GitHub marcou o PR #5 como merged por ancestralidade. A versão integrada inclui o filtro ampliado para ingredientes e produtos metalúrgicos.
- PR #7 — fontes SVG originais para banner e ícone quadrado e documentação de procedência; o PR não contém PNG exportados, conversão KTEX nem substituição do ícone no jogo. Permanece aberto.
- PR #6 — branch original preservada e PR fechado como supersedido. Sua implementação foi transportada para PR #16, com testes runtime adicionais, e integrada em `b71d06f`.
- PR #8 — validação dos enums de configuração no getter, overrides sincronizados e setter; remoção das chaves internas ainda não implementadas; harness LuaTeX direto com 103 verificações. Integrado à main em `ad0ba90`.
- Commits anteriores — correção de `GLOBAL.net_string` e leitura de `mam_plan:value()`; teste dentro do jogo ainda pendente.
- PRs de documentação/correção de interrupção devem ser conferidos no GitHub antes de marcar como integrados; o estado do GitHub é a fonte da verdade.

## Referências técnicas pesquisadas para armazenamento

As referências abaixo são usadas para orientar arquitetura e testes, não para copiar código ou assets:

- **DST Storage Viewer** — agrega quantidades de itens de contêineres marcados por minisigns e sincroniza os dados do servidor para a interface do cliente via mod RPC. Referência: https://github.com/Syrnnik/DST-Storage-Mod
- **Container Finder** — faz a busca real no servidor, envia posições de contêineres aos clientes (não GUIDs de outra simulação), usa IDs de requisição para descartar respostas antigas e permite configurar raio e categorias de contêiner. Referência: https://github.com/dbilici/dst-container-finder
- **DST Container API** — documentação da configuração de widgets e `itemtestfn`, usada para conferir a forma de registrar filtros de contêiner. Referência: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/containers
- **DST Container component** — documentação de slots, inserção/retirada, abertura/fechamento e estado do componente. Referência: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/components/container

### Decisões arquiteturais derivadas da pesquisa

1. O servidor deve ser a fonte de verdade para inventário, quantidade, localização e qualquer retirada.
2. O cliente deve receber apenas dados de apresentação; nunca confiar em uma contagem enviada pelo cliente para consumir materiais.
3. Não usar GUIDs do servidor como identificadores de entidades no cliente. Para destaque visual, enviar posições e resolver localmente; para operações, validar novamente a entidade no servidor.
4. Usar IDs de requisição para ignorar respostas atrasadas e evitar que uma busca antiga substitua uma busca mais recente.
5. Limitar a busca por raio e por tipos de contêiner suportados. A retirada futura precisa revalidar distância, acessibilidade, propriedade/permissão, quantidade disponível e espaço de destino no instante da operação.
6. Fazer primeiro consulta somente leitura; implementar retirada e integração com fabricação apenas depois de desenhar uma transação atômica no servidor que não possa duplicar nem perder itens.


## Registro de execução — 2026-11-07 (revalidação do repositório)

- `main` revalidada após as integrações em `b71d06f7b8c7c41844314944702e49a3d61455d5`; PRs #1, #2, #3, #4, #8, #9, #10, #11, #13, #14, #15 e #16 estão integrados.
- PR #1 foi integrado à `main`. Também estão integrados #2, #3, #4, #8, #9, #10, #11, #13, #14, #15 e #16. O PR #5 foi incorporado pelo #13; a implementação do #6 foi carregada pelo #16 e o #6 original foi fechado como supersedido. Apenas o PR #7 permanece aberto para finalizar PNG/KTEX e trocar a arte efetiva.
- Branches observadas incluem `main`, `docs/complete-metals-more-roadmap`, `fix/smelter-interruption-leftovers`, `test/smelting-module-harness`, `fix/allow-ambiguous-smelting` e `fix/smelter-server-stack-setting`, além das branches dos outros sistemas.
- Busca de issues abertas não retornou issues. O status combinado de `main` não reportou checks; a consulta de workflow runs para esse commit também retornou lista vazia. Isso significa “nenhum check reportado”, não aprovação de CI.
- A auditoria da matriz continua documentando as 18 receitas. O PR #9 agora carrega diretamente `smelting.lua` e `smelting_products.lua`; seu harness expandido executou 75 assertions com Lua 5.1: 75 aprovadas, 0 falhas.
- O módulo real `smelting.lua` já possui harness versionado com stubs mínimos. A execução validou consumo, sobras, receitas mistas, pré-requisitos, nitre, gemas, limites e previsão com configuração do servidor; isso valida a lógica isolada, não a integração no motor DST.
- Nenhuma alteração de gameplay, balanceamento, API do DST ou outro mod foi feita nesta execução. A auditoria do algoritmo real de consumo/lote continua sendo a próxima tarefa técnica; os testes in-game, multiplayer, save/load real e UM Beta continuam pendentes.


## Registro de execução — 2026-11-07 (continuação: PRs #9–#11)

- `main` revalidada no commit `380cd6cbf1da6bd02fe214ab362978fd54d61378`. A atualização recente da Lovable apenas registrou no `roadmap.md` a divisão combinada de trabalho; nenhuma alteração de gameplay da Lovable foi encontrada nessa atualização.
- PR #9 — harness versionado que carrega os módulos reais `smelting.lua` e `smelting_products.lua`; 81/81 assertions aprovadas no snapshot integrado. Integrado em `98b280e`.
- PR #10 — corrige previsão cliente de pilhas, cargas ambíguas e receitas externas sem custo/peso declarado. CI no head final `0a73cf7`: aprovado, incluindo 14 assertions de previsão e regressão de peso. Integrado em `9c30f0b`; testes dentro do DST/multiplayer continuam pendentes.
- PR #11 — sincroniza `acceptsstacks` com `mam_batch` do servidor e atualiza o widget quando o netvar chega depois do setup inicial. Integrado em `19fe9c6`; o teste de 16 assertions foi executado novamente pelo workflow completo do PR #13, junto aos demais harnesses. Ordem real de netvar e multiplayer continuam pendentes.
- PRs #3, #9, #10 e #11 foram integrados, respectivamente, em `708e0ea`, `98b280e`, `9c30f0b` e `19fe9c6`. A branch temporária de validação integrada passou 135/135 assertions. Depois da integração, o workflow completo do PR #13 também passou no head exato `3ad2b9e`, executando os harnesses disponíveis da main combinada, incluindo o teste de 16 assertions da configuração do baú da forja. Esses resultados não substituem testes dentro do DST.
- A inspeção de API confirma que o DST configura `acceptsstacks` tanto no componente do servidor quanto na réplica do cliente; o caminho de widget setup do cliente precisa ser validado no jogo para confirmar o instante de entrega do netvar.
- Nenhum teste in-game, multiplayer real, save/load real ou compatibilidade com UM Beta foi executado nesta etapa. Essas validações permanecem pendentes no “mundo de testes de mod”.
- A próxima etapa é a validação no mundo de testes do DST: fundição em lote, consumo/retorno de sobras, interrupção, martelamento, save/reload e multiplayer host/cliente. Não marcar compatibilidade integral apenas com os harnesses isolados.


### Nota de auditoria — previsão de pilhas no cliente

A revisão da API DST confirmou que o tamanho de pilhas é sincronizado ao cliente pela réplica `stackable`. O antigo caminho em `MAMForecast.container_items` consultava somente `item.components.stackable`, que é o componente autoritativo do servidor; isso podia reduzir uma pilha inteira a uma unidade na previsão do cliente. A correção está no PR #10 e usa `item.replica.stackable`, mantendo fallback para chamadas no servidor. A confirmação final depende do teste com o cliente real no mundo de testes.


### Nota de auditoria — sincronização tardia do widget

O PR #11 foi ampliado para cobrir uma corrida possível entre o primeiro `WidgetSetup` da réplica e a chegada da string `mam_plan`. O cliente escuta `mamplandirty` e só refaz `WidgetSetup` quando o valor `mam_batch` recebido difere do atual `acceptsstacks`; mudanças apenas de fase/resultado não devem reconfigurar o widget. A validação do evento e da ordem real de replicação ainda exige uma sessão host/cliente.


### Sincronização das branches de PR — 2026-11-07 (BRT)

- PRs #2, #3, #5, #6, #7 e #8 receberam merge commits normais da `main` atual (`380cd6cbf1da6bd02fe214ab362978fd54d61378`) para eliminar a divergência de cinco commits. As alterações de cada PR foram preservadas; nenhum histórico foi reescrito e nenhum PR foi integrado.
- PR #4 também contém a `main` atual como ancestral após sincronização da branch de documentação.
- Revalidação posterior: PRs #2, #3, #4, #9, #10, #11, #13, #14, #15 e #16 foram integrados. PR #5 foi incorporado pelo #13. PR #6 foi fechado como supersedido após o código ser transportado e integrado pelo #16. PR #7 continua aberto; a arte SVG não substitui ainda o ícone KTEX. Não assumir que branches antigas estão sincronizadas: comparar cada PR com a main atual antes de qualquer integração.
- Não foram encontrados workflow runs nem status checks para os heads verificados. Isso continua significando ausência de CI reportado, não aprovação automática.


### Continuação — cobertura direta do ciclo de vida da forja

- PR #3 foi ampliado com `dst-mods/tests/smelter_component_lifecycle_test.lua`: harness que carrega o componente real `scripts/components/smelter.lua` e substitui apenas o planejador, configuração/log e APIs de entidade/contêiner do DST por stubs.
- O novo harness contém 22 assertions para consumo exato de pilhas (parcial e total), recusa de plano inválido sem consumir carga, as duas políticas de sobras ao interromper, retomada de save com tempo positivo, conclusão expirada adiada, precedência do estado pronto para colher e reset de save sem produto.
- O teste é novo e foi revisado estaticamente, mas ainda não foi executado com LuaTeX. A execução do callback adiado em stub não comprova a ordem real de callbacks do sistema de save do DST.
- PR #3 foi integrado em `708e0ea`. O harness do componente real passou 22/22 assertions no GitHub Actions; a execução in-game do ciclo save/load continua pendente.

## 13. Automação metalúrgica e fabricação metálica — requisito adicionado em 2026-11-08

### Papel do baú metalúrgico
- O baú de minérios/armazenamento metalúrgico é uma infraestrutura de abastecimento e organização para a automação futura da forja, não apenas um contêiner de conveniência.
- Manter filtros para todos os ingredientes e produtos registrados pela metalurgia. A integração futura com fabricação deve consumir itens reais do servidor e reservar/retirar materiais atomicamente.

### Integração com coletor/robô vanilla do DST
- Planejar integração nativa entre a forja do Metals and More e o robô/coletor padrão citado pelo usuário, quando esse mecanismo estiver ativo no mundo.
- Antes de codificar, identificar o prefab, componente, eventos e API vanilla exatos. Não presumir o nome nem simular um robô novo se o pedido é integração com um sistema padrão existente.
- A integração deve ser opcional/segura quando o mecanismo vanilla não estiver presente, e funcionar sem dependência externa quando o recurso estiver desativado.
- A forja deve continuar autoritativa no servidor; validar alcance, propriedade, permissões, capacidade, combustível/tempo, estado da máquina e disponibilidade de materiais. Prevenir duplicação, perda, consumo repetido e produção gratuita.

### Receitas individuais de itens metálicos
- Inventariar os itens metálicos vanilla e do Metals and More que existirem no jogo, incluindo minério, poeira, fragmentos, lingotes, ligas, componentes e equipamentos metálicos.
- Para cada item elegível, avaliar receita individual na bancada do Metals and More, com custo, estação, tecnologia e progressão próprios, justos e balanceados.
- Não duplicar receitas existentes sem motivo, não transformar a bancada em conversor universal e não substituir a forja quando o processamento metalúrgico for a etapa correta.
- Criar uma matriz de item → receita atual → estação atual → estação pretendida → custo original → custo proposto → justificativa/balanceamento antes de alterar receitas.

### Dependências e ordem
1. Estabilizar a forja, previsão, consumo, interrupção e save/load.
2. Validar o baú e o filtro de ingredientes/produtos no jogo.
3. Inventariar itens metálicos e revisar bancada de armas/bancada de guerra; definir receitas individualizadas.
4. Identificar e testar o mecanismo vanilla do coletor/robô.
5. Projetar abastecimento e retirada atômicos entre baú, forja e coletor; implementar em etapas pequenas.
6. Validar host/cliente, multiplayer, desconexão, save/load e compatibilidade com UM Beta.

Essa adição complementa o plano original; não autoriza pular as etapas de estabilidade, balanceamento e testes.

## 14. Integração nativa com os robôs coletores vanilla — arquitetura 2026-11-08

- O alvo primário é o W.O.B.O.T. (`storage_robot`); considerar também o W.I.N.bot (`winona_storage_robot`). Ambos usam a tag `storagerobot`, mas têm sistemas de energia diferentes.
- O comportamento vanilla foi verificado em `storage_robot.lua` e `storage_robot_common.lua`: o robô só guarda em contêineres `chest`/`pack` compatíveis que já contenham pelo menos uma unidade do mesmo prefab, tenham espaço, estejam em ponto passável e na mesma plataforma. O robô executa ações vanilla PICKUP/STORE e consome seu próprio combustível.
- O baú metálico integrado é compatível como destino se mantiver o tipo `chest`, a tag `_container` do componente e não receber tags vanilla de exclusão. O jogador precisa semear cada prefab que deseja que o robô recolha; não criar itens-semente gratuitamente.
- O robô não alimenta diretamente um container de cooker. Fluxo planejado: robô coleta no chão → baú metálico recebe → forja consulta/consome materiais do baú → produto retorna ao baú ou fica em saída segura quando cheio.
- A forja só deve iniciar lotes automáticos com um `storagerobot` ativo/operacional na área configurada; identificar estado de energia/atividade por variante. Sem robô, manter a forja manual.
- Usar a previsão e o plano de consumo existentes; retirar materiais atomicamente no servidor, devolver em falha e impedir que dois lotes reservem a mesma pilha. Não patchar prefabs vanilla nem substituir funções globais.
- Especificação completa, regras de compatibilidade e testes obrigatórios: `docs/design/WOBOT_METALLURGY_AUTOMATION.md`.


## 15. Execução do modo Rewrite — PR #16 integrado em 2026-11-08

- O PR #16 transportou para uma branch baseada na main atual as alterações de Rewrite originalmente preparadas no PR #6, preservando a branch original e evitando integrar código a partir de uma base antiga.
- O harness `dst-mods/tests/loot_rewrite_runtime_test.lua` carrega os módulos reais `mam/loot_guard.lua`, as declarações de `initialise/modded_drops.lua` e o arquivo real `scripts/prefabs/newrocks.lua` com stubs mínimos de registro do DST.
- O teste cobre 18 tabelas vanilla de Rewrite, gates por fonte, normalização, exceções de árvore de mármore/tubarão, Auto/Always de hounds com UM, master switch e autoridade do servidor.
- GitHub Actions no head `f05d7b7` passou: parsing Lua 5.1 de todos os arquivos do mod e suíte completa de regressão, incluindo o novo harness.
- Isso é um teste runtime de Lua com stubs, não uma sessão real do DST. Worldgen, loot real, UM Beta, multiplayer e balanceamento em mundo continuam pendentes.
- O PR #6 original foi fechado como supersedido; sua branch e commits permanecem preservados. O PR #16 está integrado em `b71d06f`.
