# Automação de forja com W.O.B.O.T. e W.I.N.bot

Status: implementação opt-in na proposta #51; testes de contrato/CI em andamento; ainda sem validação in-game.
Atualizado: 2026-11-15.

## 1. Alvos vanilla

| Robô | Prefab | Condição de ativação |
|---|---|---|
| W.O.B.O.T. | `storage_robot` | Tag `storagerobot`, componente `fueled` não vazio e robô não recolhido |
| W.I.N.bot | `winona_storage_robot` | Tag `storagerobot`, combustível/energia disponível, implantado e `_isactive` verdadeiro |

A integração detecta a tag vanilla `storagerobot`; não cria robô substituto e não altera os prefabs vanilla. O robô funciona como condição de presença/energia para a automação da forja.

## 2. Decisão de produto vigente: qualquer baú compatível

**Não existe exigência de baú exclusivo de minério.** A automação pode usar qualquer baú/contêiner compatível próximo:
- baús vanilla;
- Marble Chest do Metals and More;
- Dragonfly Chest;
- baús de outros mods;
- contêineres do tipo `pack` que não estejam marcados como armazenamento portátil excluído.

A seleção usa o componente container e seus contratos, não uma whitelist de prefab. O contêiner precisa ter tipo `chest` ou `pack`, aceitar itens e estar na mesma plataforma. São excluídos contêineres `INLIMBO`, `NOCLICK`, `DECOR`, `companion`, `portablestorage`, `readonlycontainer` ou queimados.

O antigo `metal_storage_chest` permanece registrado somente para compatibilidade com saves antigos; não tem receita para mundos novos e não é requisito para automação.

## 3. Fluxo implementado

1. A opção `mam_robot_smelting` vem desligada por padrão.
2. O smelter verifica se há W.O.B.O.T. ou W.I.N.bot ativo e abastecido dentro de 8 unidades e na mesma plataforma.
3. A forja enumera ingredientes metalúrgicos registrados nos baús/contêineres compatíveis próximos, ordenados por distância.
4. O planner autoritativo calcula o resultado e a lista exata de ingredientes a reservar.
5. Os ingredientes são transferidos para a forja; falha parcial executa rollback para os contêineres de origem ou fallback no chão junto à máquina.
6. A forja inicia um lote pelo mesmo componente transacional usado no modo manual. O robô não escolhe novamente a receita.
7. Ao concluir, a forja procura o contêiner compatível mais próximo com capacidade suficiente e deposita o produto.
8. Se não houver espaço, o produto permanece pronto na forja para retirada manual.

O sistema não recolhe itens do chão: a coleta do chão continua sob responsabilidade vanilla do W.O.B.O.T./W.I.N.bot. A automação de Metals and More alimenta a forja diretamente a partir dos contêineres.

## 4. Segurança e preservação de itens

- Toda retirada, reserva, consumo e depósito é autoritativo no servidor.
- Apenas itens reconhecidos por `smelting.IsSmelterIngredient` podem ser retirados.
- O plano escolhido pelo servidor é reutilizado; não há segunda rolagem que possa mudar o produto após mover os ingredientes.
- A transferência valida cada slot, quantidade e capacidade; em falha, tenta devolver o que foi movido e usa o chão próximo como último fallback.
- A forja não esvazia inventários de jogadores, companheiros, armazenamento portátil ou contêineres read-only.
- A saída não é destruída quando o baú está cheio; permanece na forja.
- Se o robô ficar sem energia, for recolhido, quebrar ou sair do alcance, novos lotes automáticos param. Um lote já iniciado continua até conclusão segura.
- O modo manual permanece disponível sem robô.
- O host pode desligar a automação pela configuração.

## 5. Limites conhecidos da implementação atual

- O sistema escolhe qualquer baú/pack compatível por proximidade; não há seleção manual de baú preferido nem prioridade configurável.
- O rollback de ingredientes pode usar outro contêiner de origem disponível ou deixar o item no chão perto da forja; ainda não há garantia de retorno ao slot exato original.
- A implementação não substitui o comportamento vanilla de coleta do W.O.B.O.T.; apenas usa a presença/energia do robô como habilitador.
- A busca está limitada a 8 unidades e à mesma plataforma.
- A automação ainda precisa de testes in-game com W.O.B.O.T., W.I.N.bot, baús vanilla, Marble Chest, Dragonfly Chest e baús de mods de terceiros.

## 6. Testes obrigatórios antes de considerar concluído

- W.O.B.O.T. abastecido e W.I.N.bot implantado/ativo separadamente.
- Automação desligada por padrão e desligável pelo host.
- Baú vanilla, Marble Chest, Dragonfly Chest e um baú modded com `type="chest"`.
- Baú/pack cheio, read-only, queimado, portátil, de companheiro e em outra plataforma.
- Ingredientes em vários baús; consumo exato e ausência de duplicação.
- Falha no meio da transferência e rollback.
- Produto cabe/não cabe no baú; saída permanece recuperável.
- Save/reload durante fundição, saída pronta e rollback pendente.
- Dois jogadores tentando iniciar/colher ao mesmo tempo.
- Robô recolhido, sem combustível, quebrado ou fora do alcance durante e antes do lote.

## 7. Fontes técnicas

- `storage_robot.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/storage_robot.lua
- `storage_robot_common.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/storage_robot_common.lua
- `winona_storage_robot.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/winona_storage_robot.lua
- API: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/storage_robot
- API: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/winona_storage_robot
