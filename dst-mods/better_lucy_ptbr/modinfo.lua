name = "Better Lucy - Leal, Excêntrica e Possessiva [PT-BR]"
description = [[
Uma reforma completa na personalidade da Lucy, o machado do Woodie.
Tradução para Português do Brasil + correções.

Novidades:
• Mais de 450 falas da Lucy em português
• O Woodie responde a Lucy de vez em quando
• Volume da voz da Lucy: Normal / Baixo / Muito baixo / Mudo
• Falas originais + novas / Só novas / Só originais
• Personalidade: Clássica+, Esposa, Yandere, Picante ou Tudo
• Correção: falas sumindo ou trocadas em listas grandes
• Correção: tempo de exibição da fala agora vale para todos os jogadores

Autora original: Sharethylove
Tradução e correções PT-BR: uso pessoal
]]
author = "Sharethylove (tradução PT-BR)"
version = "0.6.0-ptbr"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

client_only_mod = false
all_clients_require_mod = true
server_only_mod = false

icon_atlas = "better_lucy.xml"
icon = "better_lucy.tex"

configuration_options =
{
    {
        name = "DAMAGE_MULT",
        label = "Dano da Lucy em combate",
        hover = "Multiplica o dano normal da Lucy.",
        options =
        {
            { description = "Original", data = 1.0 },
            { description = "1,5x",     data = 1.5 },
            { description = "2x",       data = 2.0 },
            { description = "3x",       data = 3.0 },
            { description = "5x",       data = 5.0 },
        },
        default = 2.0,
    },
    {
        name = "CHOP_POWER",
        label = "Força de corte da Lucy",
        hover = "Quanto a Lucy corta a cada golpe.",
        options =
        {
            { description = "Original",    data = 2 },
            { description = "2x",          data = 4 },
            { description = "4x",          data = 8 },
            { description = "10x",         data = 20 },
            { description = "Instantâneo", data = 100 },
        },
        default = 4,
    },
    {
        name = "VOICE_MODE",
        label = "Som da voz da Lucy",
        hover = "Volume do som que a Lucy faz quando fala.",
        options =
        {
            { description = "Normal",      data = "normal" },
            { description = "Baixo",       data = "quiet" },
            { description = "Muito baixo", data = "veryquiet" },
            { description = "Mudo",        data = "muted" },
        },
        default = "quiet",
    },
    {
        name = "SPEECH_DURATION",
        label = "Tempo da fala na tela",
        hover = "Quanto tempo cada fala da Lucy fica visível.",
        options =
        {
            { description = "Original (2,5s)",       data = 2.5 },
            { description = "Um pouco mais (3,25s)", data = 3.25 },
            { description = "Mais longo (4s)",       data = 4.0 },
            { description = "Bem longo (5s)",        data = 5.0 },
            { description = "Muito longo (6s)",      data = 6.0 },
        },
        default = 3.25,
    },
    {
        name = "DIALOGUE_MODE",
        label = "Falas da Lucy",
        hover = "Junta as falas novas com as originais do jogo, ou usa só uma delas.",
        options =
        {
            { description = "Originais + novas", data = "mixed" },
            { description = "Só as novas",       data = "custom" },
            { description = "Só as originais",   data = "vanilla" },
        },
        default = "mixed",
    },
    {
        name = "PERSONALITY",
        label = "Personalidade da Lucy",
        hover = "Quais grupos de falas novas a Lucy pode usar.",
        options =
        {
            { description = "Clássica+", data = "classic", hover = "Engraçada, excêntrica e leal." },
            { description = "Esposa",    data = "wife",    hover = "Clássica+ com romance de marido e mulher." },
            { description = "Yandere",   data = "yandere", hover = "Esposa + falas ciumentas e possessivas." },
            { description = "Picante",   data = "spicy",   hover = "Yandere + duplo sentido e falas safadinhas." },
            { description = "Tudo",      data = "all",     hover = "Todas as falas novas." },
        },
        default = "all",
    },
    {
        name = "WOODIE_REPLY",
        label = "Woodie responde a Lucy",
        hover = "Chance do Woodie responder depois que a Lucy fala.",
        options =
        {
            { description = "Desligado",      data = 0 },
            { description = "Raramente",      data = 0.12 },
            { description = "Às vezes",       data = 0.25 },
            { description = "Frequentemente", data = 0.45 },
        },
        default = 0.25,
    },
}
