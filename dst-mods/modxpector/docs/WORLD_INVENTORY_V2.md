# ModXpector — contrato do inventário de mods v2

**Build de referência:** 5.0.14-dev  
**Módulo:** `workspaces/mods/modxpector/scripts/modxpector/world_inventory.lua`  
**Schema:** `modxpector/world-inventory/v2`

## Fontes e significado

| Fonte DST | Uso | O que não prova |
|---|---|---|
| `KnownModIndex:GetModNames()` | Mods conhecidos no índice local | Que estejam habilitados ou carregados |
| `IsModEnabledAny(id)` | Habilitado, forçado ou temporariamente habilitado | Que o carregamento terminou |
| `GetModsToLoad(true)` | Candidatos previstos para carregamento usando o cache | Que o `modmain.lua` carregou sem erro |
| `GetModInfo(id)` | Nome, versão, API e flags de lado | Identidade de Workshop por si só |
| `GetServerModNames()` / `GetClientModNames()` | Classificação de lado | Lista de mods ativos; pode incluir desabilitados |
| `GetModDependencies(id, false)` | Dependências diretas | Que cada dependência esteja habilitada |
| `DoesModExistAnyVersion(id)` | Existência no índice, quando disponível | Que a dependência esteja carregada |
| `ModManager.enabledmods` | Mods observados na lista de carregados | API pública estável; é campo interno e pode não existir |
| `ModManager.failedmods` | Falhas de inicialização observadas | Causa-raiz fora da mensagem/stack registrada |

`GetModsToLoad` é chamado exclusivamente com `true`. A forma sem cache pode consultar diretórios e alterar estruturas internas de controle; não é necessária para o inventário passivo.

## Estados

- `loaded`: presente em `ModManager.enabledmods`.
- `failed`: presente em `ModManager.failedmods`, com mensagem limitada e sanitizada.
- `candidate_not_observed_loaded`: previsto para carregar, mas não encontrado na lista de carregados quando essa lista existe.
- `enabled_not_observed_loaded`: habilitado, mas não encontrado na lista de carregados quando ela existe.
- `candidate`: candidato conhecido, mas a lista de carregados não está disponível.
- `enabled_not_confirmed`: habilitado, mas a API de carregados não está disponível.
- `disabled`: habilitação foi consultada e retornou falso.
- `unknown`: não há evidência suficiente para classificar.

`enabled`, `load_candidate` e `loaded` são tri-state: `true`, `false` ou `nil` quando a fonte não pôde ser consultada. Os campos `*_known`/`capabilities` deixam a disponibilidade explícita.

## Dependências

- `missing_dependencies`: somente quando `DoesModExistAnyVersion` confirma ausência.
- `disabled_dependencies`: dependência existente, mas `IsModEnabledAny` confirma que não está habilitada.
- `unverified_dependencies`: não foi possível confirmar existência nem habilitação.

Assim, dependência instalada porém desabilitada não é reportada como inexistente. O relatório do servidor mantém os avisos separados: ausente, instalada mas não habilitada e não confirmada.

## Identidade e limites

- `workshop_id` só é extraído quando o nome do diretório corresponde exatamente a `workshop-` seguido de dígitos.
- `client_only_mod` e `server_only_mod` definem elegibilidade por lado; listas de classificação não são usadas como prova de ativação.
- A coleta é somente leitura: não abre arquivos de outros mods, não muda configurações e não executa `GetModsToLoad(false)`.
- Até 400 entradas são incluídas; `truncated` sinaliza inventários maiores. A contagem `known` permanece total.
- Se `ModManager` ou qualquer API interna não estiver disponível, o scanner degrada para estado desconhecido sem transformar ausência de API em falha do mod.

## Validação

Cobertura automatizada em `tests/test_modxpector_world_inventory.lua` e `tests/test_modxpector_current_modules.lua`: duplicatas, mod instalado/desabilitado, client-only, server-only, Workshop ID, candidatos, carregados, falhas, API ausente/lançando erro, dependência ausente e dependência instalada porém desabilitada. A validação no jogo real continua pendente.
