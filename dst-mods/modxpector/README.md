# ModXpector

Mod nativo de diagnóstico para Don't Starve Together (PC), independente dos mods de gameplay.

**Versão da fonte:** 5.0.14-dev  
**Estado:** build de desenvolvimento; validação dentro do DST real ainda pendente.  
**Identificador interno:** `dst_mod_inspector`.

## O que está incluído

- Inventário de mods conhecidos, habilitados e candidatos a carregamento.
- Estados de carregamento observados e falhas, quando as estruturas internas do jogo estão disponíveis.
- Workshop ID, metadados, classificação client/server e dependências.
- Diagnóstico de servidor, sondagem opcional de TMI, snapshot de configurações e tela de inspeção.
- Virtual Player observacional/simulador e contratos de teste.
- Relatórios que distinguem evidência confirmada de inferência.

## Limites importantes

- `GetModsToLoad(true)` fornece candidatos; não prova que o carregamento terminou.
- `ModManager.enabledmods` e `ModManager.failedmods` são estruturas internas e opcionais. Se ausentes, o scanner registra estado desconhecido/não confirmado.
- A coleta é passiva: não modifica configurações nem arquivos dos mods analisados.
- A ponte local é opcional e desativada por padrão; só é consultada quando ai_bridge_enabled é ativado explicitamente.
- bridge_token.txt é uma credencial local: não a versione nem a distribua. O empacotador e o .gitignore excluem esse arquivo.
- O token é aberto apenas em modo de leitura (`io.open(..., "r")`); o mod não grava arquivos. As notas de modders da Klei para os hotfixes [651415](https://kleiforums.com/forums/topic/163362-game-update-651415/) e [653007](https://kleiforums.com/game-updates/dst/653007-r2465/) documentam a restrição de escrita e a exceção limitada a `unsafedata`.
- Conflito suspeito não é falha confirmada.
- Testes Lua automatizados não substituem validação no jogo real, em multiplayer ou em servidores dedicados.

## Testes

Requer Lua 5.1.4. Na raiz do repositório:

```bash
LUA_BIN=lua5.1 bash dst-mods/modxpector/tests/run-lua-tests.sh
```

A suíte reproduzível contém seis testes: inventário v2, integração do relatório, UI estática, bootstrap seguro, Virtual Player ao vivo e repetição/limite de ataques. A suíte ampliada do laboratório também cobre APIs e cenários adicionais; o histórico de validação está no Obsidian.

## Empacotamento

```bash
python3 dst-mods/modxpector/tools/build_package.py
```

Gera um ZIP de teste em `dist/modxpector/`, sem incluir relatórios temporários nem dados do laboratório.

## Documentação

- [Contrato do inventário v2](docs/WORLD_INVENTORY_V2.md)
- [Registro de desenvolvimento e estado operacional no Obsidian](https://github.com/andrewrodrigo2003-create/cerebro-secundario/blob/main/Universos%20e%20Jogos/Don't%20Starve%20Together/04%20-%20Projetos%20e%20Mods/DST%20Mod%20Inspector/DST%20Mod%20Inspector%20%E2%80%94%20Desenvolvimento%20at%C3%A9%205.0.md)


## IA local e Virtual Player

O fluxo de teste assistido por IA usa o backend local do Cérebro Secundário e Ollama em loopback. A integração permanece desativada por padrão.

1. Configure a ponte local seguindo [a documentação da ponte no Cérebro Secundário](https://github.com/andrewrodrigo2003-create/cerebro-secundario/blob/feature/modxpector-local-ai-bridge-2026-11-24/docs/modxpector-local-ai-bridge.md).
2. Nas opções do ModXpector, ative **IA local para executar testes automáticos** e **Modo de testes controlados**.
3. Entre no mundo, abra o ModXpector com F6 e selecione **IA / Testes**.
4. Informe o objetivo e revise as allowlists de prefabs e ações.
5. Clique em **Gerar plano com IA e executar**. O Ollama gera um plano, o Master valida o esquema/allowlists e o Virtual Player executa as etapas no cliente local.
6. Consulte o relatório retornado pelo backend e os marcadores AI_TEST_PLAN_QUEUED, GAME_TEST_PLAN_ACCEPTED, VIRTUAL_PLAYER_FINISHED e GAME_REPORT_SAVED nos logs.

O perfil inicial é limitado a coletar grama (grass, cutgrass, PICKUP) e confirmar o item no inventário. Isso é um teste funcional de ponta a ponta, não uma suíte completa de compatibilidade de mods. O plano é rejeitado se uma ação, prefab, receita ou pós-condição não passar pelas validações. O usuário deve revisar o objetivo e as permissões antes de executar; não use o modo automático em um mundo principal sem backup.
