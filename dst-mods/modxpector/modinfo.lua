name = "ModXpector"
description = "Offline-first DST mod engineering, diagnostics and automated test runner."
author = "ModXpector Team"
version = "5.0.14-dev"
forumthread = ""
api_version = 10

dst_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true
all_clients_require_mod = true
client_only_mod = false
server_only_mod = false

-- Keep the same configuration declaration pattern as the proven 21.2.23 mod.
-- DST evaluates modinfo.lua in a restricted environment; avoid helper libraries.
local keys = {
    { description = "F5", data = "KEY_F5" },
    { description = "F6", data = "KEY_F6" },
    { description = "F7", data = "KEY_F7" },
    { description = "F8", data = "KEY_F8" },
    { description = "F9", data = "KEY_F9" },
    { description = "F10", data = "KEY_F10" },
}
keys[#keys + 1] = { description = "A", data = "KEY_A" }
keys[#keys + 1] = { description = "B", data = "KEY_B" }
keys[#keys + 1] = { description = "C", data = "KEY_C" }
keys[#keys + 1] = { description = "D", data = "KEY_D" }
keys[#keys + 1] = { description = "E", data = "KEY_E" }
keys[#keys + 1] = { description = "F", data = "KEY_F" }
keys[#keys + 1] = { description = "G", data = "KEY_G" }
keys[#keys + 1] = { description = "H", data = "KEY_H" }
keys[#keys + 1] = { description = "I", data = "KEY_I" }
keys[#keys + 1] = { description = "J", data = "KEY_J" }
keys[#keys + 1] = { description = "K", data = "KEY_K" }
keys[#keys + 1] = { description = "L", data = "KEY_L" }
keys[#keys + 1] = { description = "M", data = "KEY_M" }
keys[#keys + 1] = { description = "N", data = "KEY_N" }
keys[#keys + 1] = { description = "O", data = "KEY_O" }
keys[#keys + 1] = { description = "P", data = "KEY_P" }
keys[#keys + 1] = { description = "Q", data = "KEY_Q" }
keys[#keys + 1] = { description = "R", data = "KEY_R" }
keys[#keys + 1] = { description = "S", data = "KEY_S" }
keys[#keys + 1] = { description = "T", data = "KEY_T" }
keys[#keys + 1] = { description = "U", data = "KEY_U" }
keys[#keys + 1] = { description = "V", data = "KEY_V" }
keys[#keys + 1] = { description = "W", data = "KEY_W" }
keys[#keys + 1] = { description = "X", data = "KEY_X" }
keys[#keys + 1] = { description = "Y", data = "KEY_Y" }
keys[#keys + 1] = { description = "Z", data = "KEY_Z" }

configuration_options = {
    {
        name = "open_key",
        label = "Tecla para abrir o ModXpector",
        hover = "Atalho para abrir ou fechar o painel. F6 é o padrão.",
        options = keys,
        default = "KEY_F6",
    },
    {
        name = "show_debug_info",
        label = "Informações técnicas detalhadas",
        hover = "Exibe detalhes adicionais no painel de diagnóstico.",
        options = {
            { description = "Sim", data = true },
            { description = "Não", data = false },
        },
        default = true,
    },
    {
        name = "test_mode",
        label = "Permitir execução de testes controlados",
        hover = "Autoriza a execução de cenários controlados pelo Virtual Player. A análise da IA embarcada funciona independentemente desta opção.",
        options = {
            { description = "Desativado", data = false },
            { description = "Ativado", data = true },
        },
        default = false,
    },
    {
        name = "collect_runtime_components",
        label = "Observar componentes em runtime",
        hover = "Registra, de forma limitada e somente leitura, a criação de componentes selecionados. Desativado por padrão; requer recarregar o mundo após alterar.",
        options = {
            { description = "Desativado", data = false },
            { description = "Ativado", data = true },
        },
        default = false,
    },
    {
        name = "max_spawn_count",
        label = "Limite de itens por solicitação de teste",
        hover = "Limita a quantidade de itens criados por uma única solicitação.",
        options = {
            { description = "5", data = 5 },
            { description = "10", data = 10 },
            { description = "20", data = 20 },
        },
        default = 10,
    },
}
