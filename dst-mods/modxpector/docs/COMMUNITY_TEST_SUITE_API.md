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
- `allowed_actions`: até 10; o perfil inicial permite somente `WALKTO`.
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
