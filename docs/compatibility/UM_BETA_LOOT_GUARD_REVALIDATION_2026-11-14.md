# UM Beta — revalidação da integração de loot do Metals and More

**Data:** 2026-11-14  
**Projeto externo:** `Uncompromising-Survival/UncompromisingMode`  
**Branch consultada:** `utw-beta`  
**Commit consultado:** `6b5ce6a91845d37f926001cf76776e18d8b702a8`  
**MAM:** PR #51, HEAD-base `e929a83694c408afdc389260e59aebcc9df2c8dd`

## Evidência confirmada no código atual do UM Beta

1. `modmain.lua` define explicitamente `GLOBAL.UMCommonFns = require("tools/um_commonfns")`. A detecção de MAM por `GLOBAL.UMCommonFns ~= nil` corresponde ao global publicado pelo beta atual consultado.
2. `postinit/prefabs/firehound.lua` e `icehound.lua` registram `AddSimPostInit` para definir as tabelas compartilhadas `hound_fire` e `hound_cold`; ambas incluem a gema correspondente com chance `0.3`.
3. `postinit/prefabs/shark.lua` adiciona `rockjawleather` por `inst.components.lootdropper:AddChanceLoot("rockjawleather", 1)`.
4. `postinit/components/lootdropper.lua` envolve `DropLoot`, chama `GenerateLoot()` quando não recebe uma lista pronta e depois encaminha a lista para o método vanilla. Não substitui `AddChanceLoot` nem elimina a lista de chance do componente.
5. No script DST consultado, `LootDropper:AddChanceLoot` insere entradas em `self.chanceloot`; `GenerateLoot` processa a lista de chance e também o loot de tabela compartilhada. São caminhos distintos que podem coexistir.

## Resultado da auditoria do MAM

- A guarda `M.HasUncompromising()` usa o mesmo global publicado pelo branch atual do UM: **compatível com a interface observada**.
- Hounds em `Auto` cedem ao UM; `Always` adiciona os fragmentos do MAM de propósito. Isso evita duplicação no padrão sem impedir a escolha explícita do host.
- O tubarão recebe `sharkscale` via `AddChanceLoot`, enquanto o UM adiciona `rockjawleather` pelo mesmo mecanismo com prefab diferente. Não há colisão direta entre os nomes.
- O wrapper de `DropLoot` do UM preserva o fluxo de `GenerateLoot` quando não recebe lista pronta. A integração aditiva MAM não substitui esse wrapper.

## Limites e ações

- Esta revisão é leitura estática de fontes, não execução conjunta dentro do DST.
- O teste `loot_rewrite_runtime_test.lua` já simula `GLOBAL.UMCommonFns` e verifica hounds Auto/Always e a preservação das tabelas UM no modo Rewrite.
- A PR #52 adiciona correção separada para atomicidade da migração de receitas. O CI atual de Lua filtra PRs cujo destino é `main`; como #52 tem como destino a branch da #51, não há execução automática confirmada para este patch. Não declarar testes aprovados até executar o harness por uma via válida.
- Sem testes locais do usuário neste período, manter a #51 em draft e não promover a versão como pronta para jogo.
- Revalidar esta evidência sempre que o commit da branch `utw-beta` mudar.
