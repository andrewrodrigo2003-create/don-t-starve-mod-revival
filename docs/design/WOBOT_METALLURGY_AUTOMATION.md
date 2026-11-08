# Integração do W.O.B.O.T./W.I.N.bot com a forja

Status: arquitetura proposta; nenhuma alteração nos robôs vanilla e nenhuma automação de gameplay implementada.
Data: 2026-11-08.

## 1. Alvos vanilla

| Robô | Prefab | Papel | Energia |
|---|---|---|---|
| W.O.B.O.T. | `storage_robot` | Robô coletor/organizador encontrado no Junk Yard e reparado | `fueled` vanilla |
| W.I.N.bot | `winona_storage_robot` | Variante autônoma de Winona | sistema de energia/circuito de Winona |

Ambos usam a tag `storagerobot`. A integração deve preferir detectar essa tag e, quando necessário, tratar estado ativo/energia por variante. Não criar um robô substituto e não sobrescrever o prefab vanilla.

## 2. Regras reais do armazenamento vanilla

O código vanilla `prefabs/storage_robot_common.lua` define a procura de contêiner com estas condições:

- O destino precisa ter a tag `_container`.
- Tipos aceitos: `chest` ou `pack`.
- Não pode ter tags de exclusão vanilla como `companion`, `portablestorage`, `NOCLICK`, `DECOR` ou `INLIMBO`.
- O contêiner precisa estar aberto para receber itens (`canbeopened`) ou declarar `canacceptgivenitems`.
- O contêiner precisa já conter pelo menos uma unidade do mesmo prefab (`container:Has(item.prefab, 1)`).
- Precisa ter espaço para a pilha (`CanAcceptCount`).
- Robô, item e contêiner precisam estar em pontos passáveis e na mesma plataforma.

O W.O.B.O.T. procura o item, encontra um contêiner que já tenha o mesmo prefab, executa ações vanilla `PICKUP` e `STORE`, fecha os contêineres e consome combustível de acordo com distância e tempo.

### Consequência para o baú metálico

- O baú de 25 espaços é um destino compatível se o prefab continuar com tipo `chest`, tag `_container` fornecida pelo componente e sem tags de exclusão.
- Para cada tipo de material que o jogador quer que o robô recolha, o baú precisa ser pré-semeado com pelo menos uma unidade desse prefab. Um baú completamente vazio não é escolhido pelo robô para um item que ainda não contém.
- A lista de materiais aceitos pelo `itemtestfn` do baú continua sendo a proteção adicional. O robô não deve ser usado para contornar esse filtro.
- O robô não armazena diretamente em qualquer container de cooker. Portanto, não presumir que ele alimentará a forja diretamente.

## 3. Fluxo de automação proposto

```text
Chão / itens dropados
        │
        ▼
W.O.B.O.T. ou W.I.N.bot ativo
        │ coleta e classifica pelo item-semente
        ▼
Baú metálico (25 slots)
        │
        ▼
Forja Metals and More
        │ consulta receitas e reserva ingredientes
        ▼
Fundição autoritativa no servidor
        │
        ▼
Baú metálico (saídas) ou saída da forja se cheio
```

### Responsabilidades

**Robô vanilla**
- Continuar responsável apenas por recolher itens do chão e armazená-los segundo suas regras vanilla.
- Continuar responsável por seu combustível, bateria, movimentação, alcance, sono, wake e estado quebrado.
- Não receber patches globais ou alterações diretas em `storage_robot.lua`, `winona_storage_robot.lua` ou `storage_robot_common.lua`.

**Baú metálico**
- Aceitar somente ingredientes e produtos registrados pela metalurgia.
- Ser compatível com a classificação vanilla do robô.
- Preservar conteúdo ao salvar/carregar e ao ser destruído, sem duplicação ou perda.
- Permitir que o jogador mantenha item-semente por prefab que deseja recolher.

**Forja**
- Detectar robôs `storagerobot` ativos na área configurada, sem depender de um único prefab.
- Procurar somente baús metalúrgicos explicitamente compatíveis; não esvaziar baús comuns do jogador.
- Reutilizar a previsão e o plano de consumo já existentes em `smelting.lua`/`mam/forecast.lua`.
- Reservar/remover os ingredientes atomicamente no servidor antes de iniciar o lote.
- Se a forja não puder iniciar, devolver todos os ingredientes reservados ao mesmo contêiner ou a um fallback seguro.
- Se o lote for interrompido, aplicar a política de sobras/consumo já definida pela forja.
- Depositar o produto no baú quando houver espaço; caso contrário, manter o produto na saída segura da forja. Nunca destruir nem duplicar a saída.
- Quando o robô ficar sem energia, for recolhido, quebrar ou sair da área, pausar novos lotes automáticos sem cancelar uma fundição já iniciada de forma insegura.

## 4. Regras de segurança e balanceamento

1. Toda retirada e depósito é autoritativa no servidor.
2. Um ingrediente só pode ser reservado por um lote; impedir dois lotes de consumir a mesma pilha.
3. A previsão do cliente é apenas visual; não autoriza consumo.
4. Não criar materiais nem itens-semente automaticamente. O jogador fornece a unidade-semente.
5. A automação deve respeitar o alcance de trabalho do robô e da forja, distância, plataforma e capacidade do baú.
6. O combustível/energia do robô continua sob controle vanilla; o mod não deve drenar ou recarregar o robô por fora.
7. Não retirar itens de containers que não tenham a tag específica do baú metálico.
8. Manter o modo manual da forja disponível mesmo sem robô no mundo.
9. O modo automático deve ser configurável e desligável pelo host/servidor.

## 5. Testes necessários antes de integrar gameplay

- W.O.B.O.T. ativo com item-semente: coleta item compatível e deposita no baú metálico.
- Baú vazio: W.O.B.O.T. não o escolhe até existir uma unidade-semente do prefab.
- Item não metalúrgico: baú rejeita e o robô não o deposita.
- Baú cheio: nenhum item desaparece; robô segue comportamento vanilla.
- Forja consome do baú uma única vez e produz o resultado correto.
- Falha ao iniciar, interrupção, martelo e save/load não duplicam nem perdem materiais.
- Produto não cabe no baú: fica na saída segura da forja.
- Robô sem combustível/bateria, quebrado, recolhido ou fora de alcance: novos lotes automáticos pausam.
- Teste em servidor dedicado e cliente remoto, com dois jogadores tentando iniciar lotes ao mesmo tempo.
- Teste de W.O.B.O.T. e W.I.N.bot separadamente, incluindo suas diferenças de energia.
- Teste em mesma plataforma e em plataformas diferentes.

## 6. Fontes técnicas

- `storage_robot.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/storage_robot.lua
- `storage_robot_common.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/storage_robot_common.lua
- `winona_storage_robot.lua`: https://raw.githubusercontent.com/vietnd69/dst-scripts/main/prefabs/winona_storage_robot.lua
- API: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/storage_robot
- API: https://vietnd69.github.io/dst-api-webdocs/docs/game-scripts/prefabs/winona_storage_robot