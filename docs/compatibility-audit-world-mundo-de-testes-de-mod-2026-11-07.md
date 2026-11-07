# Metals and More Reforged — auditoria de compatibilidade
Data: 2026-11-07
Mundo de teste: **mundo de testes de mod**
Jogo: Don't Starve Together, build 762172 (Windows)
Mod em foco: Metals and More Reforged 2.9.3
Ambiente reportado: 57 mods habilitados; Uncompromising Mode `on the rocks! v1.6 testing v6.0.3.9`.

## Escopo e preservação
- Alterações de código devem ficar restritas a Metals and More Reforged.
- Não editar Hydrated/Dehydrated, Better Lucy, Uncompromising Mode, Woodie - Better Skill Tree, APIs ou quaisquer outros mods.
- A lista de mods abaixo veio do relatório enviado pelo usuário; ainda não foi possível inspecionar diretamente os diretórios locais do computador.
- Não declarar compatibilidade integral nem teste in-game sem evidência real.

## Incidente A — interação com a forja (confirmado no código)
Mensagem em tela:
`scripts/mam/forecast.lua:86: attempt to call field 'mam_plan' (a userdata value)`
Cadeia envolvida: container_opener, container_classified, prefab `metal_smelter`, jogador Woodie.
Causa: `inst.mam_plan` é criado como `net_string(...)`, portanto é uma netvar. O consumidor chamava `inst.mam_plan()` como função Lua comum.
Correção aplicada em `dst-mods/metals_and_reforged/scripts/mam/forecast.lua`: leitura alterada para `inst.mam_plan:value()`.
Commit: `3937a6b27cb8e129dd25778837ea4170be2e7397`.
Estado: commit salvo em `main`; ainda precisa de validação no jogo, em single-player e multiplayer se aplicável.

## Incidente B — personagem sem colisão / andando sobre água (relatado pelo usuário)
Severidade: alta; não confirmado por log específico até o momento.
Observações do código do Metals and More:
- `scripts/prefabs/metal_smelter.lua` chama `MakeObstaclePhysics(inst, 1)` no prefab da forja, não no jogador.
- `initialise/modded_playerpost.lua` adiciona um listener de `onattackother` para possível spawn de inimigo; não altera Physics, collision masks ou locomotion do jogador.
- Não há evidência nos trechos inspecionados de que Metals and More remova colisão do personagem.
Hipóteses ainda abertas: interação envolvendo Woodie, Woodie - Better Skill Tree (Workshop 3516850707), Woodie Transformation Skins (Workshop 3658175649 e 3732704679), outro mod que modifica player physics, ou estado/transição de transformação.
Próxima evidência necessária: log completo do momento em que a colisão falha e reprodução controlada no mesmo mundo, comparando Woodie com outro personagem e isolando apenas os mods suspeitos sem editar seus arquivos.

## Incidente C — crash anterior do Woodie - Better Skill Tree
Relatório anterior: `modmain.lua:1405 attempt to call method 'SetSpellFn' (a nil value)`, mod Workshop 3516850707 versão 0.5.
Este incidente é separado do crash da forja. Não há confirmação de que tenha causado a falha de colisão.

## Mods listados no relatório do mundo
1. Glassic API (2521851770) — 4.3
2. [API] Gem Core (1378549454) — 5.1.47
3. Woodie Transformation Skins (3658175649) — 20261106
4. Woodie - Better Skill Tree (3516850707) — 0.5
5. Crash Never Mind (3377689002) — 26-8-30
6. Barra de Vida Épica (1185229307) — 104
7. Accomplishments (2843097516) — 3.6-a
8. DST Minus API (2806524702) — 1.1.2
9. Shoetime (3150203711) — 1.1.5
10. Witch Broom Fly (3828144951) — 1.1
11. Better Ice Flingomatic+ (3358135145) — 1.4
12. Berg Cub (1577400707) — 1.2.0
13. Better Kitchen - Batch Crock Pot & Smart Fridge (3816225553) — 0.4.2
14. Better Lucy PT-BR (mod local better_lucy_ptbr) — 0.6.0-ptbr
15. Checkmate Arsenal (3490072866) — 1.1.9
16. Chesspiece Reskinner (3005590415) — 1.4
17. Compromising Statue (3568885383) — 1.0
18. DST Equipment Switcher (503919639) — 1.33
19. DST Sodium (3793502052) — 0.5.1
20. Enhanced Ocuvigils (3114706349) — 1.0.5
21. Find Me (3815052004) — 1.0.2
22. Hybrid Chester (3770426774) — 1.1.0
23. Metals and More Reforged (mod local metals-and-reforged) — 2.9.3
24. Modify Items Stack (2774093373) — 2025.9.6.1
25. MyDock (3805536936) — 1.0.0
26. Potterswheel Plus (3602958211) — 3.5
27. Reasonable DST (3801497710) — 1.02
28. Rope Bridge (2420839895) — 1.12
29. Skeletons Plus (3341044868) — 1.0
30. Storage Bags (3624411781) — 1.3
31. Vacuum Chester [REWORK] (3074440113) — 1.1
32. Woodie Transformation Skins (3732704679) — 20260515
33. World Generation Compatibility (3798999176) — 1.0.1
34. Wormhole Marks [DST Continued] (3571706033) — 1.0.0a
35. Yearly Seasonal Events (2934824468) — 1.3.10
36. [DST] Telescope (3189988118) — 1.5
37. 墙体学 (3832334662) — 1.4
38. 晨昏线 · Terminus Light (3761111244) — 0.3.0
39. 更好的死亡体验 / BetterDeathExperience (3677734114) — 2.1
40. 潮起潮落 (3708564521) — 1.0.3
41. 简易血条(重构版) (3759757365) — 0.6.7
42. 龙鳞烤炉 / Scaled Stove (3535620803) — 1.0.3
43. Celestial Tools (2456874720) — 1.3.9
44. Candy Bag Buffet (3831710987) — 26.11.05.1
45. Simple Storage (3383078008) — 26.02.11
46. Better Clock(re)works (3667524475) — 1.3.1
47. Uncompromising Mode (3193922031) — on the rocks! v1.6 testing v6.0.3.9
48. Tudo um Pouco / Odds and Ends (3815942726) — 1.2-a (alpha)
49. Colorful Lantern Skins (2394728927) — 6.0
50. Global Positions (CompleteSync) (3138571948) — 2.4.7
51. Performance Pack (2847908822) — 26-6-18
52. Insight (2189004162) — 6.0.7
53. Meat & Egg Skins Pack (3566227956) — 1.0
54. Better UM Cursed Items (3701828503) — 26.09.26
55. Configurable SkillTrees (3125803295) — 2.4.2
56. Don't Starve: Dehydrated (3004639365) — alpha 1.2.7.1g.7
57. Extra Equip Slots Plus + (2823530744) — 1.0.7

Observação: o relatório também identifica o jogador como Woodie e lista dois mods de skins de Woodie em versões distintas. Confirmar no gerenciador do jogo se são intencionais e evitar desativar/alterar qualquer mod sem autorização.

## Plano de compatibilidade
1. Corrigir e validar a leitura da netvar da forja (commit já salvo).
2. Auditar todos os pontos de integração do Metals and More: prefabs, componentes, actions, recipes/techtree, containers/UI, drops, física e hooks de jogador.
3. Priorizar interações sugeridas pelos logs: Gem Core, Glassic API, Woodie Transformation Skins, Woodie - Better Skill Tree, Uncompromising Mode Beta e mods de armazenamento/inventário.
4. Investigar a colisão de Woodie separadamente; não atribuir causa ao Metals and More sem reprodução.
5. Executar verificações estáticas/sintáticas disponíveis e registrar limitações.
6. Testar no mundo `mundo de testes de mod` com cópia única do Metals and More habilitada. Não tocar em Better Lucy, Dehydrated ou Uncompromising Mode.

## Estado honesto
- Correção de netvar: implementada e commitada; teste in-game pendente.
- Colisão do personagem: causa ainda desconhecida; nenhuma alteração de física aplicada.
- Auditoria dos 57 mods: inventário registrado; análise individual e testes de integração ainda pendentes.
- Acesso ao computador local: não disponível nesta sessão; usar os arquivos/logs locais fornecidos pelo usuário para fechar diferenças entre instalação e repositório.
