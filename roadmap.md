# Roadmap — mods de Don't Starve Together

Ordem pedida: um mod por vez, finalizar antes de começar o próximo.

- [x] Better Lucy — tradução PT-BR, Woodie responde, falas mais picantes, correções (entregue: dst-mods/better_lucy_ptbr)
- [x] Don't Starve: Dehydrated — usuário informou que recebeu atualização oficial e está ativo; NÃO mexer
- [ ] Metals and More – Reworked & Fixed (dst-mods/metals_and_reforged) — EM ANDAMENTO
  - Nome provisório da atualização: **Metals and More Reforged**
  - Plano mestre completo: [docs/METALS_AND_MORE_REFORGED_MASTER_PLAN.md](docs/METALS_AND_MORE_REFORGED_MASTER_PLAN.md)
  - [x] Correções de inicialização/netvars e proteção de receitas contra sobrescrita de outros mods
  - [x] Forja em lotes, previsão e controles básicos de lote/tempo/sobras (implementação; validação in-game pendente)
  - [x] Livro/craftbook e bancada de guerra existem no código (auditoria e validação pendentes)
  - [x] Drops adicionais configuráveis em modo aditivo (auditoria por fonte e validação pendentes)
  - [~] Correção das opções por fonte e hounds Auto/Always no modo Rewrite (PR #6 aberto; testes in-game pendentes)
  - [ ] Restauração e auditoria integral de todas as mecânicas metalúrgicas originais
  - [~] Harnesses Lua 5.1 da forja, ciclo de vida, previsão e sync de pilhas aprovados; validar ainda no DST save/load, interrupções e multiplayer servidor/cliente
  - [ ] Concluir livro metalúrgico de consulta
  - [ ] Auditar progressão, bancada de armas e bancada de guerra
  - [x] Baú metalúrgico de 25 espaços integrado via PR #13; filtro aceita ingredientes e produtos registrados da metalurgia. CI completo aprovado; testes in-game/save-load/multiplayer pendentes.
  - [ ] Consulta de depósitos próximos, retirada segura e integração com containers externos, com distância/permissões/autoridade do servidor
  - [ ] Planejar o baú como infraestrutura de abastecimento da automação futura da forja
  - [ ] Identificar o robô/coletor vanilla citado pelo usuário e projetar integração nativa quando ativo no mundo
  - [ ] Inventariar todos os itens metálicos vanilla/mod e criar matriz de receitas individuais balanceadas para a bancada do Metals and More
  - [ ] Completar configurações sem opções placebo
  - [ ] Compatibilidade real com Uncompromising Mode Beta e conjunto de mods do mundo de teste
  - [ ] Pesquisa de referências e documentação de mudanças
  - [ ] Testes completos e relatório final com limitações

- [ ] Trabalhar junto com o ChatGPT no Metals and More — divisão combinada (ChatGPT: forja em lotes e previsão; Lovable: o resto)

Não alterar Hydrated/Dehydrated, Better Lucy, Uncompromising Mode ou quaisquer outros mods.
