# Uncompromising Mode Public Beta — contrato de loot dos cães — 2026-11-17

## Fonte examinada

- Repositório público: https://github.com/Uncompromising-Survival/UncompromisingMode
- Branch: utw-beta.
- Commit da branch observado: 62d2df0274466a98fdcf694e85cfd986a7f939c6.
- modmain.lua blob: b35c7bc6821f9ad2fbe800c72ed6548ddb7de00a; linha 22 publica GLOBAL.UMCommonFns = require("tools/um_commonfns").
- postinit/prefabs/firehound.lua blob: 5bd2cd353e1cb362e18fb9ac5a0e5f309081ba42; linhas 4–11 registram hound_fire via AddSimPostInit e incluem redgem com chance 0.3.
- postinit/prefabs/icehound.lua blob: d1c63a6adb0b91b6c87b463d6920bd73e6a28c36; linhas 4–11 registram hound_cold via AddSimPostInit e incluem bluegem com chance 0.3.
- modinfo.lua blob: 0bda95a4ed2e8a6d60c6291e596ccd01fe0ee7c2; declara versão 6.0.4 na branch beta.

A página Steam da Public Beta usa o Workshop ID 3193922031:
https://steamcommunity.com/sharedfiles/filedetails/?id=3193922031
O repositório é uma referência de código público, não uma garantia de que cada byte corresponda ao pacote Workshop atualmente instalado.

## Contrato aplicado pelo MAM

- M.HasUncompromising() detecta o contrato público por GLOBAL.UMCommonFns ~= nil; a branch beta publica esse campo no modmain.
- Os drops extras de firehound e icehound usam AddChanceLoot aditivo, não substituem a tabela compartilhada do UM.
- Configuração Auto (padrão): quando UM é detectado, o MAM não adiciona seus quatro rolls de redgem_shard/bluegem_shard, evitando duas fontes de gemas na mesma criatura.
- Configuração Always: adiciona os fragmentos mesmo com UM; é uma escolha explícita do jogador.
- O modo Rewrite não deve substituir o loot do UM quando a opção está em Auto; Always permite a sobreposição explicitamente.

## Regressão automatizada

Novo harness: dst-mods/tests/um_beta_loot_compatibility_test.lua.

Cenários:
1. Sem UM, Auto mantém os quatro rolls originais do MAM.
2. Com GLOBAL.UMCommonFns, Auto não adiciona fragmentos aos cães de fogo/gelo.
3. Com UM e Always, os quatro rolls são adicionados.
4. Rewrite + Auto cede ao UM.
5. Rewrite + Always adiciona somente por opt-in explícito.

O harness foi incluído em Metals and More Lua checks e MAM stacked PR contracts.

## Limite

A validação usa o contrato público do repositório beta e stubs de runtime. Não substitui o teste in-game com a versão Workshop instalada, load order real e configuração efetiva do servidor.
