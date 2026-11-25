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
- A IA principal é embarcada em Lua e funciona offline, sem Ollama, Python, FastAPI, servidor, modelo local, token ou serviço externo.
- O primeiro núcleo analisa inventário e estados dos mods, identifica falhas/dependências/flags e cria uma fila determinística de investigação somente leitura.
- O Virtual Player é um executor separado. A integração do planejador de testes com ele está em desenvolvimento; a IA ainda não deve ser descrita como completa.
- Conflito suspeito não é falha confirmada.
- Testes Lua automatizados não substituem validação no jogo real, em multiplayer ou em servidores dedicados.

## Testes

Requer Lua 5.1.4. Na raiz do repositório:

```bash
LUA_BIN=lua5.1 bash dst-mods/modxpector/tests/run-lua-tests.sh
```

A suíte reproduzível executa sete arquivos de teste: motor de IA embarcada, inventário v2, módulos/configuração, UI estática, bootstrap seguro, Virtual Player ao vivo e repetição/limite de ataques. A suíte ampliada do laboratório também cobre APIs e cenários adicionais; o histórico de validação está no Obsidian.

## Empacotamento

```bash
python3 dst-mods/modxpector/tools/build_package.py
```

Gera um ZIP de teste em `dist/modxpector/`, sem incluir relatórios temporários nem dados do laboratório.

## Documentação

- [Contrato do inventário v2](docs/WORLD_INVENTORY_V2.md)
- [API declarativa de suites comunitárias](docs/COMMUNITY_TEST_SUITE_API.md)
- [Registro de desenvolvimento e estado operacional no Obsidian](https://github.com/andrewrodrigo2003-create/cerebro-secundario/blob/main/Universos%20e%20Jogos/Don't%20Starve%20Together/04%20-%20Projetos%20e%20Mods/DST%20Mod%20Inspector/DST%20Mod%20Inspector%20%E2%80%94%20Desenvolvimento%20at%C3%A9%205.0.md)


## IA embarcada e Virtual Player

A IA principal está dentro do próprio mod, em Lua. Ela observa o inventário de mods e os diagnósticos disponíveis, aplica regras e heurísticas auditáveis, classifica evidências e prioriza investigações. Não requer Ollama, Python, servidor local, modelo, chave ou conexão externa.

1. Entre no mundo e abra o ModXpector com F6.
2. Selecione **IA / Testes**.
3. Clique em **Executar análise da IA embarcada**.
4. Consulte os achados, a confiança de cada diagnóstico e a próxima investigação priorizada.
5. Mods comunitários podem registrar suites declarativas pela API documentada em [COMMUNITY_TEST_SUITE_API.md](docs/COMMUNITY_TEST_SUITE_API.md). O ModXpector só seleciona suites de mods ativos e carregados.
6. Se houver uma suite compatível, ative **Modo de testes controlados** e clique em **Executar suite**. O Master valida permissões, allowlists e pós-condições antes de iniciar o Virtual Player.

A análise não altera arquivos ou configurações de outros mods e não executa código dos mods analisados. As suites são dados declarativos, sem callbacks ou código arbitrário; o perfil atual só permite WALKTO e verificações observacionais. "Não foi observado carregamento" é tratado como suspeita, não como prova de falha. A ausência de achados não comprova compatibilidade total.

**Proteção do mundo principal:** a opção **Modo de testes controlados** continua desativada por padrão. As suites comunitárias atuais usam apenas WALKTO e verificações observacionais; embora WALKTO não destrua objetos, ele move o personagem real do jogador e também exige **Confirmar mundo de laboratório descartável**. Qualquer plano com ações (incluindo movimento, ataque, coleta, crafting, spawn ou desbloqueio de receitas) exige essa segunda opção, igualmente desativada por padrão. Essa confirmação não cria nem detecta automaticamente um mundo isolado: crie um mundo/save separado para laboratório e ative a opção somente nele. Nunca habilite esse modo na sua partida principal. A documentação oficial da Klei permite separar clusters por -cluster e diretórios de configuração por -conf_dir: https://support.klei.com/hc/en-us/articles/360029556192-Dedicated-Server-Command-Line-Options-Guide.

O contrato interno do Virtual Player também reconhece as ações DST `STORE`, `TAKEITEM` e `TAKESINGLEITEM`, além das pós-condições `player_inventory_has_item` (itens carregados, equipados e no overflow; exclui baús abertos) e `container_has_item` (contagem no contêiner-alvo). Essa cobertura foi verificada em Lua 5.1/harness, não no jogo real. A API de suites comunitárias continua limitada a `WALKTO`; retirar itens de baús por slot ainda requer um adaptador específico de `ContainerReplica` e permanece pendente.
