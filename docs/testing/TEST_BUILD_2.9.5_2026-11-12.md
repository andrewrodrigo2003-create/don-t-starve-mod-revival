# Metals and More Reforged 2.9.5 — teste local

**Build:** PR #50, branch `fix/smelter-refund-retry-2026-11-11`  
**Commit testado:** `594c6ace575e9bc9b0c45026b9fb01b326eeb9c1`  
**Pacote:** `metals-and-more-reforged-2.9.5.zip`  
**SHA-256 do artefato externo do GitHub:** `a8ef5513533ab41b119b1383d4ba85b926d15c61fc8b9450949f41436b45f377`  
**Tamanho:** 6.520.736 bytes

## Instalação

1. Baixe o artefato do workflow: https://github.com/andrewrodrigo2003-create/don-t-starve-mod-revival/actions/runs/43275633835/artifacts/13971540102
2. Extraia o ZIP do artefato. Dentro dele estará o pacote instalável `metals-and-more-reforged-2.9.5.zip`.
3. Dentro do artefato estará o ZIP instalável. Extraia esse ZIP na pasta de mods do DST. O resultado deve ser uma pasta `metals_and_reforged` contendo `modinfo.lua` e `modmain.lua`.
4. Desative/remova da lista de mods ativos qualquer cópia duplicada/antiga de Metals and More. Não deixe Workshop antigo e pasta local carregarem simultaneamente.
5. Não substitua nem edite Hydrated/Dehydrated, Better Lucy ou Uncompromising Mode.

## Teste recomendado

Use o mundo **mundo de testes de mod**. Faça primeiro uma execução com o conjunto mínimo já usado para testar o mod e depois repita com o conjunto de compatibilidade.

### A. Forja e prévia
- Abrir a forja vazia; verificar se a interface não apresenta erro.
- Colocar cobre/ferro e conferir nome do produto sobre a imagem e quantidade prevista no canto inferior direito.
- Testar misturas ambíguas; a UI deve indicar possibilidades sem prometer um resultado fixo.
- Ativar/desativar lote e testar pilhas, limite e crescimento de tempo.
- Iniciar fundição, tentar inserir itens enquanto processa e confirmar que o container permanece bloqueado.
- Colher o resultado e conferir quantidade exata e sobras.
- Interromper por martelo/dano e conferir devolução dos materiais.
- Salvar/recarregar durante processamento e quando estiver pronto para colher.
- Testar inventário cheio e saída sem espaço; não pode sumir nem duplicar produto.

### B. Armas e personagens
- Testar o machado normal de Woodie.
- Testar as quatro armas da Forja: ataques normais, ataques especiais, AOE, parry, durabilidade e cooldown conforme configuração.
- Confirmar que não existe mais o antigo arremesso global da Lucy vindo do Metals and More.
- Testar Willow/Bernie e habilidades relacionadas, sem atribuir ao MAM erros que apontem para outro mod.

#### C. Baú metalúrgico
- Confirmar que a opção Metal storage chest está ligada (default On).
- Fabricar o baú na estação de alquimia e confirmar os 25 espaços.
- Guardar minérios, poeiras, fragmentos, lingotes e ligas registrados.
- Confirmar que itens comuns/estranhos são rejeitados.
- Martelar a estrutura e verificar se o conteúdo é devolvido uma única vez.
- Salvar/recarregar com itens dentro.

## D. Compatibilidade
- Repetir com Uncompromising Mode Public Beta **6.0.3.9** (branch `utw-beta`) habilitado. Para a primeira passagem, manter `mam_drop_hounds = Auto` e `mam_recipe_overrides = Safe`; testar também `celestialitems_revert` do UM ligado para confirmar que o MAM cede em glasscutter/moonglassaxe.
- Observar receitas, drops, tech trees, forja, UI, containers e erros de carregamento.
- Repetir com Improved Scaled Furnace/Scaled Stove e mods de armazenamento/inventário usados no mundo.
- Verificar se o antigo Metals and More da Oficina está desativado, evitando duas cópias do mesmo mod.

### E. Logs
Após o teste, guardar:
- `client_log.txt`
- `server_log.txt` (se host/servidor)
- lista de mods habilitados e configuração do MAM
- descrição curta do passo exato que causou o problema

Relatório de compatibilidade estático: [UM Public Beta 6.0.3.9](../compatibility/UNCOMPROMISING_MODE_PUBLIC_BETA_6.0.3.9_AUDIT_2026-11-12.md). A auditoria de código não substitui o teste conjunto dentro do DST.

## O que esta build não contém ainda

- Livro metalúrgico informativo multi-página.
- Desconstrução reversível dos metais.
- Consulta próxima a depósitos e integração automática com a forja/robôs.
- Automação de forja com W.O.B.O.T./W.I.N.bot.
- Matriz completa de receitas individuais e estações.
- Ícone convertido para KTEX.

O `metal_storage_chest` está novamente craftável por opção de configuração (default On) e usa o filtro metalúrgico. Consulta próxima a depósitos e automação W.O.B.O.T./W.I.N.bot ainda não estão implementadas.

## Limite de validação

CI passou em Lua 5.1, harnesses e simuladores; nenhum teste foi executado no motor real do DST. Esta build é candidata para teste local, não lançamento final nem compatibilidade integral certificada.
