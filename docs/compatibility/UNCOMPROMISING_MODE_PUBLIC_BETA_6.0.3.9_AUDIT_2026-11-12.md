# Compatibilidade — Uncompromising Mode Public Beta 6.0.3.9

**Auditoria de código:** 2026-11-12  
**Projeto auditado:** [Uncompromising Mode](https://github.com/Uncompromising-Survival/UncompromisingMode)  
**Branch de beta:** `utw-beta`  
**Commit da branch observado:** `fc09a5924fbb096a4dcb3582e22907b9c94a73ca`  
**Versão em modinfo:** `6.0.3.9`  
**Mod alvo:** Metals and More Reforged 2.9.5, branch `fix/smelter-refund-retry-2026-11-11`.

## 1. Resultado resumido

A implementação atual do MAM já possui defesas reais para três pontos de integração que são sensíveis no UM Beta: receitas que o UM reequilibra, loot de hounds elementais e loot de tubarão. Os mecanismos do MAM são majoritariamente aditivos ou tardios e não precisam editar o código do UM.

Isso é evidência de compatibilidade arquitetural, não certificação de compatibilidade in-game. A branch beta do UM tem milhares de arquivos e o teste real ainda depende do mundo local do usuário.

## 2. Receitas — colisão conhecida e proteção existente

Fontes UM consultadas:
- `init/init_recipes/init_recipes.lua`: importa `recipe_changes`, `recipes`, `recipes_ia` e receitas específicas de personagens.
- `init/init_recipes/recipe_changes.lua`: altera diretamente entradas de `GLOBAL.AllRecipes`.
- Caso confirmado: quando `celestialitems_revert` está ligado, o UM altera `glasscutter.ingredients` para boards + moonglass e também muda `nounlock`; altera ainda `moonglassaxe.nounlock`.

Proteção do MAM:
- `scripts/mam/recipe_guard.lua` mantém assinaturas vanilla e só aplica override quando a receita ainda corresponde à assinatura original.
- `initialise/modded_recipes.lua` aplica os overrides no `AddSimPostInit`, depois das declarações de modmain, e possui fallback para a primeira task do world.
- Se o UM alterou a lista de ingredientes, o MAM deve ceder e registrar o motivo; não deve reescrever a receita beta.
- O MAM altera apenas `ingredients` quando aplica o override; não precisa apagar o `nounlock` do UM.

**Teste local obrigatório:** habilitar `celestialitems_revert` no UM, manter `mam_recipe_overrides = 1`, verificar glasscutter e moonglassaxe na interface e conferir o log MAM. O resultado esperado é o override MAM ceder quando a assinatura UM divergir da vanilla. Repetir com o override MAM em Off. Não usar Always durante o teste de compatibilidade inicial.

## 3. Drops — hounds elementais

Fontes UM consultadas:
- `postinit/prefabs/firehound.lua`: no `AddSimPostInit`, define a loot table compartilhada `hound_fire`, incluindo `redgem` com chance 0.3.
- `postinit/prefabs/icehound.lua`: no `AddSimPostInit`, define `hound_cold`, incluindo `bluegem` com chance 0.3.
- As duas fontes também alteram comportamento de combate/ataques, mas isso é independente da tabela de loot.

Proteção do MAM:
- `initialise/modded_drops.lua` declara fragmentos de gema para firehound/icehound com `skip_if_um = true`.
- `scripts/mam/loot_guard.lua` consulta `GLOBAL.UMCommonFns` quando a entidade é criada. O modmain do UM define esse global no carregamento, portanto a detecção ocorre tarde o suficiente para observar o UM.
- `mam_drop_hounds = Auto` (default) cede ao UM quando detectado, evitando adicionar os fragmentos do MAM sobre as gemas do UM.
- `Always` força a adição dos fragmentos mesmo com UM; isso pode aumentar o total de materiais e é escolha explícita do host. Não é o modo recomendado para validar compatibilidade.

**Teste local obrigatório:** com UM Beta ligado e `mam_drop_hounds = Auto`, matar firehound e icehound sem fogo e conferir se a tabela não recebe fragmentos duplicados do MAM. Repetir com UM desligado para confirmar o comportamento MAM normal. Não avaliar loot de hound queimando como comparação direta: o UM também transforma loot de entidades em chamas via seu wrapper de `lootdropper:DropLoot`.

## 4. Drops — tubarão e wrapper global de loot

Fonte UM:
- `postinit/prefabs/shark.lua` adiciona `rockjawleather` usando `inst.components.lootdropper:AddChanceLoot`.
- `postinit/components/lootdropper.lua` envolve `DropLoot` para a regra de loot de criaturas/entidades queimando.

Fonte MAM:
- `initialise/modded_drops.lua` adiciona `sharkscale` ao prefab `shark` por `AddChanceLoot`.
- O MAM não substitui o método global `DropLoot` nem troca a tabela do UM.

**Conclusão:** os dois drops usam entradas diferentes e o wrapper do UM continua recebendo a lista produzida pelo componente. A expectativa é preservar ambos; precisa ser testada com shark normal e shark queimando para observar as regras de fireloot.

## 5. Containers e armazenamento

Fontes UM:
- `init/init_containers.lua` define vários containers exclusivos, incluindo `um_scrapper`, e registra parâmetros em `containers.params`.
- `postinit/components/container.lua` acrescenta `DropOneItemWithTag` ao componente vanilla.

Estado MAM 2.9.6:
- A receita e a opção do `metal_storage_chest` foram removidas a pedido do usuário. O prefab/widget/tag antigos permanecem apenas para carregar saves que já contenham o baú.
- A nova automação usa containers compatíveis comuns (`chest`/`pack`) e APIs vanilla `Container:CanAcceptCount`, `GiveItem` e `RemoveItem`; não substitui `containers.params` nem edita `um_scrapper`.
- O MAM não depende de componentes privados do UM.

**Conclusão:** não foi encontrada colisão de nome/widget nos containers UM inspecionados. A automação genérica ainda precisa ser testada in-game com o conjunto de containers do usuário.

## 6. Limites

- Foram lidos `modinfo.lua`, `modmain.lua`, `init/init_recipes/recipe_changes.lua`, `init/init_recipes/init_recipes.lua`, `init/init_containers.lua`, `postinit/components/container.lua`, `postinit/components/lootdropper.lua`, `postinit/prefabs/firehound.lua`, `icehound.lua` e `shark.lua` do UM Beta.
- Não houve execução conjunta dos dois mods no motor DST.
- Não foi validada a compatibilidade com todos os mods de armazenamento, fornalhas, ActionQueue, Combined Status, Better UM Cursed Items ou com o conjunto completo de mods do mundo do usuário.
- O código-fonte do UM declara licença `Other/NOASSERTION`; esta auditoria é leitura e comparação, não autorização para copiar código ou assets.
- A branch `utw-beta` pode mudar; sempre registrar o commit usado em novos testes.

## 7. Sequência de teste recomendada no mundo local

1. MAM + UM Beta, sem outros mods de forja/armazenamento: confirmar carregamento sem erros.
2. `mam_drop_hounds = Auto`: firehound/icehound e shark normal.
3. `celestialitems_revert` ligado no UM e `mam_recipe_overrides = Safe` no MAM: glasscutter/moonglassaxe.
4. Baú antigo: apenas carregar save legado; depois testar automação em baús vanilla e containers externos.
5. Forja: lote, preview, interrupção, devolução e save/load.
6. Adicionar Improved Scaled Furnace/Scaled Stove e os mods de armazenamento usados pelo usuário, um grupo por vez.
7. Só então repetir com o conjunto completo do mundo `mundo de testes de mod`.

Registre client/server logs e não altere arquivos do UM durante a validação.
