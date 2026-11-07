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

- [x] Criar arte vetorial original para o banner e ícone quadrado, sem reutilizar a arte legada; fontes SVG e exports PNG documentados no PR #7.
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
- [~] PR #6 corrige o modo Rewrite para respeitar as opções individuais, restaurar as fontes de árvore de mármore/tubarão e preservar Auto/Always dos hounds com UM; revisão e testes in-game pendentes.
- [x] Comparação estática confirmou que as 18 tabelas originais mantêm todos os nomes e pares item/chance.
- [x] Harness LuaTeX isolado da lógica de decisão passou 9 cenários; não executa o módulo completo nem o DST.
- [x] Existe opção para normalizar rolls repetidos, desligada por padrão para preservar as probabilidades originais.
- [ ] Auditar todas as probabilidades e quantidades contra o v2.9.3, incluindo rolagens repetidas e fases de crescimento.
- [ ] Confirmar que cada fonte é coerente com o material e com o risco da criatura/bioma.
- [ ] Verificar que recursos plantados ou renováveis não criam farms de minério não intencionais.
- [ ] Verificar que nenhum item vanilla ou drop de outro mod é removido no modo aditivo.
- [ ] Confirmar o comportamento do modo Rewrite, deixando claro que ele restaura a substituição de loot tables do original.
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

- [~] Primeiro contêiner dedicado implementado em código na branch `feature/metal-storage-chest`, PR #5: 25 slots, filtro baseado em `smelting.IsSmelterIngredient`, tags `chest` + `mam_metal_storage`; draft não integrado e testes in-game pendentes.
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

**Estado encontrado na auditoria:** existem `marble_chest` e `cold_safe` como contêineres genéricos do mod. O primeiro baú metalúrgico dedicado foi adicionado em código no PR #5; consulta centralizada e integração com estações continuam sem implementação. Os defaults `mam_storage_query` e `mam_station_storage` aparecem em `mam/config.lua`, mas ainda não são consumidos por código; não expor essas opções como se funcionassem.

## 8. Configurações

- [x] Existe módulo central `mam/config.lua` e opções para lote, limite, tempo, sobras, previsão, overrides de receitas e drops.
- [ ] Auditar todas as chaves para garantir que cada opção exposta esteja conectada ao comportamento.
- [ ] Remover ou não expor opções sem implementação; nunca deixar controles placebo.
- [~] Opção `mam_metalschest` adicionada ao `modinfo.lua` no PR #5 (default on); teste no jogo pendente.
- [ ] Adicionar configurações de armazenamento/consulta somente quando os recursos estiverem implementados.
- [ ] Garantir que defaults preservem a experiência original quando a opção estiver desligada.
- [ ] Validar tipos, limites, valores ausentes, sincronização servidor-cliente e mensagens de configuração.
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
- [x] Auditoria isolada de estados de save/load da forja: 6 cenários aprovados; sem execução do componente completo/DST.
- [x] Há relatório estático e harness de prefab para o primeiro baú metalúrgico (PR #5); o harness passa em ambiente com stubs, mas ainda não testa o motor DST.
- [x] Há auditoria de Rewrite e comparação entry-by-entry das 18 loot tables (PR #6).
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
2. Fechar auditoria de mineração/drops e registrar matriz por fonte/configuração.
3. Validar craftbook, bancada de guerra e progressão.
4. Projetar e implementar o armazenamento metalúrgico em etapas pequenas, começando pelo contêiner próprio e seus filtros.
5. Implementar consulta próxima somente depois que o armazenamento básico estiver seguro.
6. Completar testes de compatibilidade, multiplayer e mundo de testes.
7. Finalizar documentação, changelog e entrega.

## Histórico de mudanças já integradas

- PR #1 — correções de consumo de nitre/moonglass/junk dust e drops completos do lote ao martelar a forja; integrado em `main` em 2026-11-07.
- PR #5 — primeiro baú metalúrgico com filtro da lista real de ingredientes da forja e harness isolado aprovado; aberto, draft, não integrado.
- PR #7 — fontes SVG originais para banner e ícone quadrado, exports PNG e documentação da cadeia de autoria; conversão KTEX e substituição do ícone no jogo pendentes.
- PR #6 — correção das opções por fonte e fontes especiais no modo Rewrite; aberto, draft, não integrado.
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
