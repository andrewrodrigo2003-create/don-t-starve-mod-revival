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
