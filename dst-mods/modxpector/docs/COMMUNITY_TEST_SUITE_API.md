# ModXpector — API declarativa de suites comunitárias

## Objetivo

Mods da comunidade podem declarar cenários de teste para o ModXpector sem instalar um modelo, servidor ou biblioteca externa. A IA embarcada lê a declaração como dados, seleciona suites pertencentes a mods ativos e pode converter um cenário aprovado em um plano do Virtual Player.

A API é opcional. Um mod sem suite continua sendo analisado pelo inventário e pelas regras passivas do ModXpector.

## Registro

O ModXpector publica no ambiente global:

- `MODXPECTOR_TEST_SUITE_API_VERSION = 1`
- `MODXPECTOR_REGISTER_TEST_SUITE(suite)`

Registre em `AddSimPostInit`, para que o ModXpector já tenha publicado a API independentemente da ordem de carregamento dos arquivos `modmain.lua`:

```lua
AddSimPostInit(function()
    local globals = GLOBAL or _G
    local register = globals.MODXPECTOR_REGISTER_TEST_SUITE
    if type(register) ~= "function" then
        return -- ModXpector não está instalado/ativo
    end

    local ok, result = register({
        schema = "modxpector/test-suite/v1",
        id = "my_mod_smoke",
        owner_mod_id = "workshop-123456789",
        title = "My Mod — smoke test",
        priority = 50,
        allowed_prefabs = { "my_mod_test_prefab" },
        allowed_recipes = {},
        allowed_actions = { "WALKTO" },
        scenarios = {
            {
                id = "approach_test_prefab",
                title = "Approach the test prefab",
                steps = {
                    {
                        kind = "action",
                        action = "WALKTO",
                        target = { prefab = "my_mod_test_prefab", radius = 12 },
                        target_required = true,
                    },
                    {
                        kind = "assert",
                        assertion = {
                            kind = "player_near_target",
                            target_step = 1,
                            radius = 4,
                        },
                        verifies_step = 1,
                    },
                },
            },
        },
    })

    print("[MyMod] ModXpector suite registration: " .. tostring(ok) .. " / " .. tostring(result))
end)
```

Substitua o Workshop ID e o prefab pelo identificador real do mod. O proprietário é autodeclarado; o ModXpector só seleciona a suite se esse ID aparecer no inventário local como mod habilitado e não observado em falha.

## Schema e limites atuais

- `schema`: obrigatório, `modxpector/test-suite/v1`.
- `id`, `owner_mod_id`: identificadores de 1–64 caracteres alfanuméricos, underscore ou hífen.
- `title`: 1–160 caracteres.
- `priority`: 0–100; maior valor ganha prioridade em caso de empate de seleção.
- `allowed_prefabs`: até 40 identificadores.
- `allowed_recipes`: até 40 identificadores.
- `allowed_actions`: até 10; o perfil atual permite somente `WALKTO` e `PICKUP`.
- `scenarios`: 1–20 cenários, cada um com 1–20 etapas.

### Etapas aceitas

O perfil inicial é intencionalmente não destrutivo:

- `action: WALKTO` com `target_required=true` e prefab incluído em `allowed_prefabs`.
- `assert: player_near_target`, `target_exists` ou `target_has_tag`, referenciando uma ação anterior.
- As asserções de estado do jogador aceitas pelo validador podem ser usadas como pós-condições observacionais.
- Toda ação deve ter uma asserção com `verifies_step` apontando para ela.
- Para asserções de alvo, `target_step` deve ser a mesma etapa indicada em `verifies_step`.

São rejeitados spawn, craft, ataque, consumo, alteração de inventário, coordenadas arbitrárias, funções, callbacks, strings de código e tipos de etapa desconhecidos. A suite é copiada para uma estrutura normalizada; o ModXpector não executa código Lua fornecido por outro mod.

## Seleção e execução

1. O ModXpector coleta o inventário local.
2. A IA seleciona suites cujo `owner_mod_id` corresponde a um mod habilitado e não observado em falha.
3. A interface mostra as suites compatíveis.
4. O usuário precisa ativar **Modo de testes controlados**.
5. Ao executar, o plano é enviado ao Master do DST.
6. O Master verifica permissão de administrador, configuração, schema, allowlists, referências e pós-condições.
7. Só após resposta positiva do Master o cliente inicia o Virtual Player.
8. O resultado é guardado na sessão local e exibido no painel.

A execução pode falhar por ausência do prefab, condições do mundo ou limitações do jogo. Isso é registrado como resultado do cenário, não como prova automática de que o mod inteiro está incompatível.

## Segurança: mundo normal versus laboratório descartável

 - O perfil comunitário atual continua limitado a WALKTO e verificações observacionais. WALKTO move o personagem real, portanto também exige laboratory_mode; apenas inspeção sem movimento/ação pode permanecer fora do laboratório.
 - test_mode é a autorização geral para iniciar testes controlados. Não significa que o mundo esteja isolado.
 - Planos com ações que alteram entidades, inventário, receitas ou o mundo exigem a opção separada Confirmar mundo de laboratório descartável (laboratory_mode), cujo padrão é desativado.
 - O ModXpector não consegue provar, apenas pelo runtime do jogo, que o save atual é descartável. O usuário precisa criar um mundo/cluster separado e habilitar a opção somente nele.
 - Para servidores dedicados, a Klei documenta -cluster para selecionar uma pasta de cluster e -conf_dir/-persistent_storage_root para separar diretórios de configuração. Master e Caves são shards do mesmo cluster, não saves isolados: https://support.klei.com/hc/en-us/articles/360029556192-Dedicated-Server-Command-Line-Options-Guide.

## Responsabilidade do mod autor

- Use um prefab de teste que já exista naturalmente no mundo ou em uma área de teste controlada.
- Declare somente prefabs e ações estritamente necessários.
- Garanta que a pós-condição realmente verifique o comportamento declarado.
- Não inclua ações destrutivas no perfil inicial.
- Não envie dados pessoais, tokens ou segredos na suite.
- A suite é uma declaração de teste, não uma certificação de compatibilidade.

## Estado atual

O registro, validação, seleção, compilação para o schema do Virtual Player e o caminho de RPC aguardando aprovação do Master estão implementados. A cobertura atual limita-se ao perfil seguro com `WALKTO` e verificações observacionais. É necessário ampliar os adaptadores de ação e pós-condição gradualmente, com testes e evidências por subsistema.


## Adaptador comunitário embutido: Friendly Skeleton - AI

O catálogo interno inclui um smoke test opcional para o Workshop **2323760467**:

- Prefab observado: `skeletonservant`.
- Pré-condições: o mod precisa estar habilitado/carregado, o prefab precisa existir no registro `Prefabs` da sessão e um Skeleton Servant precisa já estar presente no mundo.
- Cenário: o Virtual Player se aproxima do servant e verifica a distância.
- Ação permitida: somente `WALKTO`; não cria, equipa, consome, ataca ou altera entidades.
- Origem da referência: [página do mod na Oficina](https://steamcommunity.com/sharedfiles/filedetails/?id=2323760467) e descrição do mod original que identifica os nomes de spawn [808788274](https://steamcommunity.com/sharedfiles/filedetails/?id=808788274).
- O código do mod comunitário não foi copiado. O nome do prefab é tratado como candidato derivado da página original; a suite só aparece quando o runtime confirma que `Prefabs.skeletonservant` está registrado.
- O teste verifica existência do alvo e capacidade de aproximação; **não certifica** coleta, combate, mineração, persistência nem compatibilidade geral do mod.

O catálogo só apresenta suites quando o mod proprietário está ativo e todos os prefabs declarados existem no registro local. Isso evita oferecer um teste cujo alvo não está registrado.


## Integração opcional com Dev Tools (Workshop 2220506640)

O inventário faz uma sondagem somente de leitura à API pública `DevToolsAPI:GetAPIVersion()`, descrita pelo projeto comunitário `dstmodders/mod-dev-tools` (licença MIT). O ModXpector não carrega nem depende do Dev Tools.

- Se a API estiver disponível em versão documentada `<= 1`, não é criado alerta de incompatibilidade.
- Se a versão principal observada for maior que 1, a IA cria um achado **provável** para revisão da integração.
- Se o mod estiver carregado mas a API não for observada, o achado é **desconhecido/informativo**; ausência de API não é tratada como falha confirmada.
- A chamada é protegida por `pcall`; ausência da API não interrompe o inventário nem o carregamento do ModXpector.
- A integração não copia código do Dev Tools e não adiciona dependência de Workshop.


## Behavior Trees com memória de execução

O motor oferece agora `MemorySelector`, `MemorySequence`, `AsyncAction` e `ResetMemory`. Os composites mantêm o índice do filho que retornou `RUNNING`, retomam desse ponto no próximo tick e limpam o cursor quando terminam ou falham. Cada composite exige uma chave de memória única no contexto.

Essa evolução é uma implementação original inspirada conceitualmente no uso de comportamentos stateful do Artificial Wilson; nenhum código desse repositório foi copiado. Ela prepara a IA para tarefas de vários ticks sem reiniciar precondições e ramos já concluídos.


## Executor interno de tarefas diagnósticas

O motor executa automaticamente tarefas `internal_read_only` geradas pelo plano: inspecionar erro de carregamento, confirmar dependências ausentes/desativadas, revisar flags, confirmar estado de carregamento e registrar limites de evidência das APIs comunitárias. Cada execução grava status e evidência na sessão. `passed` significa que a investigação confirmou o achado, não que o mod passou em compatibilidade; `failed` significa que a evidência contradisse o achado; `inconclusive` preserva ausência de prova.

O executor não altera o mundo, não executa código de outros mods e não inicia o Virtual Player. Ações do mundo permanecem restritas às suites aprovadas pelo Master.


## Evidência dos registros de runtime

O inventário inclui uma amostra somente de leitura dos registros que o runtime expõe:

- `Prefabs`: total de chaves com nome string e até 256 nomes, ordenados alfabeticamente.
- `AllRecipes`: total de chaves com nome string e até 256 nomes, ordenados alfabeticamente.
- `ThePlayer.components`: até 128 nomes de componentes do jogador, ordenados alfabeticamente.
- Os campos `capabilities`, `counts` e `registry` indicam disponibilidade, contagem, amostra e truncamento.
- A coleta não chama hooks, não enumera entidades do mundo, não modifica tabelas e não faz polling contínuo.
- A ausência de uma tabela é registrada como indisponível; não é tratada como zero nem como erro do mod.
- As listas são amostras limitadas para diagnóstico e planejamento; não são prova de que todos os recursos de um mod funcionam.


## Observador opt-in de componentes

A opção de configuração `collect_runtime_components` permite registrar observações de componentes sem interceptar nem substituir seus métodos.

- Padrão: **desativado**. Alterar a opção requer recarregar o mundo para registrar os hooks.
- Hook: `AddComponentPostInit`, somente para a allowlist `health`, `hunger`, `sanity`, `inventory`, `container`, `builder`, `combat`, `workable`, `pickable`, `harvestable`, `growable` e `follower`.
- Evidência: nome do componente, prefab associado e tempo relativo quando `GetTime` está disponível.
- Limites: até 256 eventos; contadores continuam acumulando e eventos excedentes incrementam `dropped`.
- Falhas de registro e de callback são contadas; cada hook é registrado sob proteção de erro.
- A coleta não enumera todas as entidades, não lê código de mods, não modifica entidades/componentes e não faz polling.
- Os eventos não provam qual mod criou o prefab; a origem do código não é inferida apenas pelo nome do prefab.


O estado interno do observador permanece privado no módulo; o snapshot entregue à IA é uma cópia sanitizada e limitada. Nenhum buffer mutável é publicado em `GLOBAL`.


## API opcional de eventos de diagnóstico comunitários

Mods comunitários podem enviar observações estruturadas sem compartilhar código ou executar callbacks no ModXpector. A recepção fica desativada por padrão e precisa ser habilitada em **Configuração → Receber diagnósticos de mods comunitários**.

Exemplo de chamada:

```lua
if type(MODXPECTOR_REPORT_DIAGNOSTIC_EVENT) == "function" then
    MODXPECTOR_REPORT_DIAGNOSTIC_EVENT({
        schema = "modxpector/community-diagnostic-events/v1",
        mod_id = "workshop-1234567890",
        kind = "runtime_error",
        severity = "error",
        message = "Descrição curta do erro",
        stack = "scripts/modmain.lua:123",
        prefab = "my_mod_prefab",
        component = "workable",
    })
end
```

- Tipos aceitos: `runtime_error`, `compatibility_warning`, `capability_observed`, `test_result`.
- Severidades aceitas: `error`, `warning`, `info`. A IA nunca promove severidade declarada a crítico.
- `mod_id` é uma alegação do remetente; `source_verified` permanece sempre `false`, mesmo se o mod estiver ativo.
- Mensagem limitada a 500 caracteres; stack a 2.000; prefab/componente exigem identificadores simples.
- Buffer global limitado a 128 eventos e 20 eventos únicos por origem alegada; duplicatas são agregadas por contador.
- Padrões comuns de credenciais (`token=` e `Authorization: Bearer`) são redigidos antes do armazenamento.
- Payloads são tratados como dados, nunca executados. Eventos de erro/compatibilidade aparecem como aviso com confiança `unknown`.
- A API não substitui `print`, `error`, `pcall` ou `xpcall`, nem intercepta chamadas globais.
- Esta API é uma extensão para mods comunitários que venham a adotá-la; não implica que os mods já catalogados a implementem.


## Autorização dos RPCs de efeitos

As chamadas server-authoritative de spawn_item, spawn_entity e unlock_recipe devem incluir request_id, step_index (índice 1-based), run_id e os parâmetros específicos da operação. O Master confere esses campos contra a etapa exata do plano aprovado, confirma que a etapa ainda não foi consumida e só então executa o efeito. Uma etapa não pode ser reutilizada. Não invoque esses RPCs fora de um plano ativo aprovado; limpar o plano invalida chamadas subsequentes. Essa autorização é adicional a administrator, test_mode, laboratory_mode, allowlists e limites de taxa/quantidade.



### Coordenadas de spawn

Além da etapa exata, run_id e quantidade, o Master valida a posição. Se a etapa tiver position, o spawn deve ocorrer a até 4 unidades desse ponto; caso contrário, deve ficar a até 4 unidades da posição autoritativa do jogador no servidor. Coordenadas não numéricas, NaN, infinitas ou fora do limite são rejeitadas. A etapa não é consumida quando a validação espacial falha.


## Ação adicional liberada: PICKUP

A partir da revisão de 26/11/2026, a API aceita PICKUP em cenários declarativos, com as seguintes condições:

- O prefab do item precisa constar em allowed_prefabs e no target selector.
- target_required precisa ser true.
- A ação precisa ser verificada por player_inventory_item_count_increased.
- A assertion precisa referenciar o mesmo step da ação em target_step.
- prefab deve corresponder ao item esperado e estar na allowlist.
- count é inteiro entre 1 e 10000; o padrão é 1.
- O Master revalida suite_id, owner_mod_id, scenario_id e a allowlist de ações do servidor. Não basta o cliente declarar uma ação permitida.
- Qualquer ação do Virtual Player exige test_mode e laboratory_mode; use somente mundo descartável.

Exemplo de cenário:

```lua
{
    kind = "action",
    action = "PICKUP",
    target = { prefab = "my_mod_test_item", radius = 12 },
    target_required = true,
},
{
    kind = "assert",
    assertion = {
        kind = "player_inventory_item_count_increased",
        target_step = 1,
        prefab = "my_mod_test_item",
        count = 1,
    },
    verifies_step = 1,
}
```

A verificação mede o aumento da quantidade total daquele prefab no inventário antes/depois do step. Ela não prova identidade de GUID em cenários com pickups concorrentes do mesmo prefab; execute o smoke test em ambiente isolado, sem outras fontes simultâneas do item. Não reutilize essa contagem como prova suficiente de STORE/TAKEITEM/TAKESINGLEITEM: essas operações continuam bloqueadas até uma verificação de transferência específica.

A allowlist do servidor é independente da declaração do mod. No estado atual, suites comunitárias só podem usar WALKTO e PICKUP; ATTACK, STORE, TAKEITEM, execução arbitrária e outras ações permanecem recusadas pela camada de suites.

