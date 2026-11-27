# Don't Starve Together — Mod Revival

Repositório de engenharia e manutenção de mods para **Don't Starve Together (PC)**. O projeto começou com a intenção de recuperar mods abandonados, corrigir incompatibilidades e melhorar traduções; atualmente a principal linha de produto é **Metals and More Reforged**, dentro do ecossistema modular Beyond the Forge.

## Fonte de verdade

- `dst-mods/metals_and_reforged/` — código-fonte do mod Metals and More Reforged.
- `dst-mods/tests/` — harnesses Lua 5.1, contratos e testes de regressão do mod.
- `tests/` — testes auxiliares do repositório.
- `docs/` — arquitetura, decisões, compatibilidade, balanceamento, histórico de builds e procedimentos.
- `.github/workflows/` — parsing, harnesses, gates de compatibilidade e empacotamento automatizado.
- `AGENTS.md` — regras técnicas e limites para alterações.

## Projetos e escopo

- **Metals and More Reforged:** módulo independente; não é renomeado para Beyond the Forge.
- **Beyond the Forge:** ecossistema guarda-chuva de módulos DST independentes e distribuição unificada planejada.
- **Alvo:** DST para PC. Compatibilidade com Uncompromising Mode Public Beta é prioridade; preservar Hydrated e evitar alterações em mods de terceiros.
- **Laboratório:** separar análise estática, harness/simulador, CI, runtime automatizado e teste manual no jogo. Um teste simulado não comprova funcionamento dentro do DST.

## Estado de desenvolvimento

- A branch `main` é a referência integrada; PRs abertas em draft são propostas, não releases.
- A PR #51 consolida a linha aprovada de desenvolvimento 2.9.7. O pacote candidato 2.9.7 está destinado à validação real no DST e não é certificado; 2.9.6 permanece como referência estável até a validação in-game.
- A PR #57 reconcilia correções da War Bench, ações cliente/servidor e segurança dos workflows sobre a base da #51.
- Nenhuma dessas PRs foi mesclada ou publicada na Oficina Steam.
- O último build de jogo observado nos registros recuperados foi 762172 (x64), em 2026-11-14; confirmar o build atual antes de atribuir compatibilidade.

## Validação

1. Parsing Lua 5.1 e verificações estáticas.
2. Harnesses e contratos isolados.
3. Simulador determinístico para subconjuntos explicitamente modelados.
4. CI e verificação do pacote instalável.
5. Teste real no DST, incluindo cliente/master, mundo novo/save existente, multiplayer e combinações de mods.

Os níveis 1–4 não substituem o nível 5. Não declarar compatibilidade ampla apenas porque o CI passou.

### Laboratório local

```sh
python -B dst-mods/tests/run_lab.py --lua lua5.1 --luac luac5.1 --output dst-lab-report.json
```

O executor reúne os harnesses atuais, contratos Python, parsing e simulador, incluindo machado/cinzel e localização das bancadas. `--lua` e `--luac` também aceitam caminhos completos, inclusive no Windows. Para os três harnesses com fontes locais do jogo, acrescente `--dst-scripts "caminho/para/scripts"`; isso não inicia o DST nem comprova comportamento no motor.

O JSON guarda comandos, logs, versões das ferramentas, branch/HEAD, alterações locais e hashes dos arquivos verificados. O destino deve ser novo e seu diretório já deve existir: relatórios anteriores nunca são sobrescritos. Falhas, arquivos obrigatórios ausentes e timeouts retornam código não zero; a ausência do PNG gerado pelo pipeline continua sendo falha de assets, não um teste dispensado. CI, pacote e jogo real ficam explicitamente como não executados.

Veja [execução, categorias e limites do laboratório](dst-mods/tests/simulator/README.md). O executor é local; esta atualização não altera nem executa workflows de CI.

## Histórico de origem

A intenção original do projeto foi recuperar mods abandonados, corrigir incompatibilidades e trabalhar em traduções. Um dos mods de referência informado no início foi [o mod da Oficina Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3814815896). O placeholder antigo de URL para “mod revivido” foi removido porque não apontava para uma página válida.

## Licenças e proveniência

Não copiar código, arte, animações, textos ou assets de terceiros sem licença ou permissão explícita. Abandono, disponibilidade pública ou ausência de atualização não concedem direitos de reutilização. Registrar fonte, autor, licença e permissão antes de qualquer incorporação.

