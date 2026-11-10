# Referências de modding — Terraria, Valheim, Starbound e Factorio

Data: 2026-11-10  
Projeto-alvo: Metals and More Reforged (DST)  
Natureza: pesquisa de documentação pública e propostas arquiteturais. Nenhuma API externa deve ser copiada para DST; nenhuma mecânica ou balanceamento foi alterado.

## Resumo executivo

Esta rodada aprofundou quatro ecossistemas:
- Terraria/tModLoader: separação de conteúdo por tipos e fases explícitas de carregamento, receitas e descarregamento.
- Valheim/Jötunn: gerenciadores especializados, registro idempotente, eventos de disponibilidade de assets, sincronização e compatibilidade de rede.
- Starbound/OpenStarbound: patches de assets e scripts Lua para extensão localizada.
- Factorio: ciclo de vida dividido em settings/prototypes/runtime e execução reativa a eventos.

O padrão que mais importa ao MAM: **registro previsível + contratos pequenos + lifecycle explícito + integração opcional + testes de compatibilidade**.

## Terraria / tModLoader

### Conteúdo por responsabilidade
A classe ModItem concentra propriedades e hooks de um item e pode declarar suas receitas. ModSystem permite dividir sistemas gerais em módulos independentes, com hooks como AddRecipes, PostAddRecipes, OnWorldLoad, OnWorldUnload, ClearWorld, OnModLoad e OnModUnload.

### Fases de carregamento
A documentação distingue Load de PostSetupContent: em Load nem todo conteúdo está totalmente registrado; PostSetupContent ocorre quando o conteúdo foi preparado. PostAddRecipes é um ponto explícito para alterar receitas já adicionadas por outros mods. O carregamento também define ordem e dependências entre mods.

**Lição para MAM:** evitar acessar conteúdo de outros mods cedo demais. Onde a API DST permitir, registrar primeiro e resolver dependências depois que os prefabs/componentes necessários estiverem disponíveis. Os hooks específicos do tModLoader não existem necessariamente no DST; usar apenas como padrão de lifecycle.

### Grupos de receitas
RecipeGroup permite ingredientes intercambiáveis em uma receita. Isso é um padrão útil para categorias de material, mas só deve ser usado no MAM se a identidade metalúrgica continuar clara e se o jogador entender exatamente quais minérios podem substituir outros.

**Aplicação possível:** uma camada de dados pode declarar grupos equivalentes de material para receitas que realmente aceitem substituição. Não ampliar equivalências automaticamente; requer decisão de design e validação com UM Beta.

## Valheim / Jötunn

### Managers especializados
Jötunn fornece managers distintos para itens, receitas, prefabs, criaturas, peças, GUI, localização, minimapa, rede, sincronização e renderização. O ItemManager valida unicidade, adiciona conteúdo ao manager de prefabs e registra itens/receitas no ObjectDB. PrefabManager faz registro controlado e cacheia prefabs.

**Lição para MAM:** a futura integração entre forja, baú, livro e robô coletor deve ocorrer por contratos e interfaces conceituais pequenos, não por dependências cruzadas. Não precisamos criar um framework universal; basta evitar que cada sistema conheça detalhes internos dos outros.

### Registro e eventos
O ItemManager expõe eventos quando itens são registrados; a documentação alerta que alguns eventos ocorrem em cada recriação do ObjectDB e precisam ser desinscritos se o comportamento deve ocorrer só uma vez. PrefabManager tem eventos relacionados à disponibilidade dos prefabs vanilla.

**Lição para MAM:** não assumir que inicialização ocorre uma única vez. Callbacks e registros precisam tolerar repetição, evitar duplicatas e limpar listeners. Isso é particularmente importante em reloads, mudanças de mundo e inicializações de UI.

### Compatibilidade multiplayer e sincronização
Jötunn oferece NetworkCompatibility para declarar se o mod precisa estar nos clientes e qual nível de versão deve coincidir. Sua documentação destaca que RPCs, formatos de dados e itens novos/alterados exigem sincronização coerente. SynchronizationManager oferece sincronização inicial de dados e configuração entre servidor e clientes.

**Lição para MAM:** mesmo que o foco imediato seja mundo local, projetar a futura automação com autoridade do servidor/mundo e estado replicável em mente. Nunca confiar em UI cliente para decidir consumo/produção. Qualquer teste multiplayer futuro deve verificar versão, duplicação de itens, sincronização de estado e RPCs. Não inventar equivalentes de API DST sem conferir a implementação do jogo.

### Integração entre mods
Mod Registry/Mod Query permite descobrir prefabs de outros mods sem referenciar diretamente seus tipos. A documentação avisa que a disponibilidade de cada categoria de conteúdo depende do momento do ciclo de carregamento.

**Lição para MAM:** compatibilidade opcional deve ser descoberta em runtime, protegida por verificações e com fallback seguro. Evitar hard dependency quando o recurso pode funcionar sem o outro mod.

## Starbound / OpenStarbound

OpenStarbound documenta scripts Lua executados durante carregamento de assets e depois que as fontes foram carregadas, capazes de ler, criar e modificar assets. Também oferece arquivos .patch.lua para alterar assets JSON e imagens.

**Lição para MAM:** preferir alterações localizadas e extensões pequenas a cópias integrais de arquivos vanilla. Para DST, usar os mecanismos nativos de modding (post-init, AddPrefabPostInit, hooks e APIs suportadas) e não importar o formato de patch do Starbound. Cada alteração precisa respeitar ordem de carregamento e coexistência com outros mods.

## Factorio

A documentação oficial divide o ciclo em settings, prototype e runtime. Settings e prototypes são preparados na inicialização; runtime ocorre junto do jogo e é baseado em eventos. O jogo expõe também interface remote para comunicação entre mods.

**Lição para MAM:** separar configuração, registro de conteúdo e lógica em jogo. Preferir eventos e callbacks a varreduras constantes. Se sistemas precisarem conversar, expor um contrato público pequeno e versionável, com fallback quando o outro sistema não está presente.

## Recomendações aplicáveis ao MAM

### A. Registro idempotente
Todo registro de prefab, listener, receita ou widget deve resistir a chamadas repetidas sem duplicar estado. Registrar e desregistrar deve ter um par claro. Testar reload, world transition e reinitialization.

### B. Lifecycle como contrato
Documentar quando cada subsistema pode acessar prefabs, componentes, UI e dados de mundo. Para cada task/listener/widget, identificar proprietário, ponto de criação, ponto de cancelamento e comportamento quando a entidade desaparece.

### C. Integração opcional
Forja, baú metalúrgico, livro e robô coletor devem depender de contratos estáveis (por exemplo: consultar entradas válidas, solicitar operação, receber resultado), e não de variáveis internas de outro arquivo. Sistemas externos devem ser detectados de forma segura e nunca ser requisito para o núcleo funcionar.

### D. Autoridade e sincronização
Operações que consomem ou criam itens devem ser decididas pelo lado autoritativo do mundo. UI pode apresentar previsão, mas a execução precisa revalidar entradas e estado no momento da ação. Planejar testes futuros de multiplayer sem presumir que o modo local valida rede.

### E. Dados e equivalência de materiais
Receitas devem ter fonte declarativa única, validada automaticamente. Grupos de materiais intercambiáveis só quando houver regra de design explícita; não generalizar substituição de metais por conveniência.

### F. Compatibilidade por extensão localizada
Preferir wrappers que preservem todos os argumentos e retornos vanilla, post-init e extensões pontuais. Qualquer override global precisa ter justificativa, teste de contrato e plano de coexistência. Isso reforça a auditoria já feita dos wrappers de combate, cujos achados ainda são candidatos estáticos até confirmar a versão instalada.

### G. Testes por fase
- L0: parsing, lint, AST, inventário de assets e contratos estáticos.
- L1: funções puras, validação de receitas e cálculos.
- L2: contratos de wrappers, registro idempotente, eventos e cleanup.
- L3: harnesses com stubs para lifecycle e interações.
- L4: motor DST real em mundo descartável.
- L5: multiplayer, UM Beta e pilha de mods.
Nenhum teste L0–L3 comprova comportamento real em L4/L5.

## Próximas experiências de engenharia (sem alterar gameplay)

1. Criar teste de registro repetido para os sistemas de prefab/receita do MAM, onde a estrutura atual permitir.
2. Mapear todos os listeners, tasks e widgets por proprietário e rotina de cleanup.
3. Auditar acessos a prefabs/componentes em fases de inicialização e verificar risco de ordem de carregamento.
4. Definir contrato conceitual para comunicação futura entre forja, baú e coletor, sem implementar automação prematuramente.
5. Incluir casos de sincronização/autoridade no plano L5.
6. Não alterar dano, loot, receitas, custos ou progressão nesta rodada.

## Fontes

- tModLoader ModItem: https://docs.tmodloader.net/docs/stable/class_mod_item.html
- tModLoader ModSystem: https://docs.tmodloader.net/docs/stable/class_mod_system.html
- tModLoader Mod: https://docs.tmodloader.net/docs/stable/class_mod.html
- tModLoader loading steps: https://github.com/tModLoader/tModLoader/wiki/Mod-Loading-Steps
- Jötunn ItemManager: https://valheim-modding.github.io/Jotunn/api/Jotunn.Managers.ItemManager.html
- Jötunn PrefabManager: https://valheim-modding.github.io/Jotunn/api/Jotunn.Managers.PrefabManager.html
- Jötunn NetworkCompatibility: https://valheim-modding.github.io/Jotunn/tutorials/networkcompatibility.html
- Jötunn SynchronizationManager: https://valheim-modding.github.io/Jotunn/api/Jotunn.Managers.SynchronizationManager.html
- Jötunn Mod Registry/Query: https://valheim-modding.github.io/Jotunn/tutorials/mod-registry.html
- OpenStarbound README: https://github.com/OpenStarbound/OpenStarbound
- Factorio API lifecycle: https://lua-api.factorio.com/latest/index.html
- Factorio runtime API: https://lua-api.factorio.com/latest/index-runtime.html

## Proveniência e limites

Informações resumidas de documentação pública dos projetos citados. Recomendações para MAM são inferências arquiteturais. Não foram executados testes nos jogos de referência nem no motor DST nesta rodada. Não foi copiado código/API externa. Nenhuma alteração de gameplay foi feita.
