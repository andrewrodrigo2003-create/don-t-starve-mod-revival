-- Better Lucy - falas personalizadas (Português do Brasil)
-- Versão 0.6.0-ptbr
--
-- Os perfis são cumulativos:
-- classic = só clássico
-- wife    = clássico + esposa
-- yandere = clássico + esposa + yandere
-- spicy   = clássico + esposa + yandere + picante
-- all     = tudo
--
-- Pode adicionar quantas falas quiser em cada lista: o mod divide listas
-- grandes automaticamente para não quebrar o envio pela rede.

return
{
    classic =
    {
        equipped =
        {
            "Aí está você. Já estava com saudade da sua mão.",
            "Só eu, você e várias árvores nervosas.",
            "A gente forma uma dupla perigosamente boa, Woodie.",
            "Um passeio juntos? Que romântico. Agora me arruma uma árvore.",
            "Relaxa, Woodie. Eu vou estar sempre grudada em você.",
            "Você não precisa de outro machado. Você tem a mim.",
            "Afiei meu gênio só pra você.",
            "Woodie e Lucy. Fica mais bonito cada vez que eu falo.",
            "Se alguém perguntar, eu sou a sua favorita.",
            "Eu vi você olhando pro machado de ouro. A gente precisa conversar.",
            "Você me trouxe junto. Decisão correta.",
            "Pronta quando você estiver, lenhador.",
            "Espero que tenha alongado. Tenho planos pra esses braços.",
            "As árvores temem a gente. Como deveriam.",
            "Bora fazer lenha e umas escolhas questionáveis.",
            "Eu sou afiada, você é bonitão. Parceria eficiente.",
            "Estamos em 2026 e as árvores ainda não aprenderam.",
            "Ano novo, mesmo lenhador favorito.",
            "Woodie, eu tenho um trabalho só e sou extremamente empolgada com ele.",
            "Me segura direito. Eu tenho padrões.",
        },

        on_chopped =
        {
            "Aquela árvore estava chegando perto demais de você.",
            "Madeiraaa! Viu? Eu resolvo os problemas.",
            "Mais uma fora do nosso caminho.",
            "Belo golpe! Eu sabia que tinha escolhido o lenhador certo.",
            "De novo! Eu faria isso com você pra sempre.",
            "Ela nunca teve chance contra a gente.",
            "Você corta, eu torço. Sistema perfeito.",
            "Aquela ali tinha cara de suspeita mesmo.",
            "Viu, Woodie? Trabalho em equipe!",
            "Uma árvore a menos disputando a sua atenção.",
            "Golpe lindo. Nota dez. Sem comentários.",
            "Primeiro corta, pergunta nunca.",
            "Foi exagero? ...Nah.",
            "Que jeito de desvalorizar o terreno.",
            "Eficiente. Violento. Romântico.",
            "A floresta foi notificada.",
            "Você faz o trabalho de lenhador parecer injusto.",
            "Dou cinco folhas de bordo pra esse golpe.",
            "Você bateu. Eu gostei. Todo mundo sai ganhando.",
            "Mais uma árvore aprendendo sobre consequências.",
        },

        on_ground =
        {
            "Woodie? Amor? Você esqueceu uma coisa importante.",
            "O chão não é lugar pro seu machado favorito.",
            "Me pega antes que eu leve isso pro lado pessoal.",
            "Você vai voltar pra me buscar. Isso não é uma pergunta.",
            "Estou esperando com muita paciência. Quase toda.",
            "Woodieeee... eu tô vendo você indo embora.",
            "Tá bom. Vou ficar aqui deitada e lembrar disso pra sempre.",
            "Eu sei que você não me abandonaria de propósito.",
            "Essa terra está acabando com o meu acabamento.",
            "Cinco estrelas pro chão da floresta. Bem rústico. Me pega.",
            "Eu sou um machado, não enfeite de jardim.",
            "Você sabe o quanto esse ângulo é humilhante?",
        },

        on_dropped =
        {
            "Ah. A gente vai fazer isso de novo?",
            "Eu fui grudenta demais? Não responde.",
            "Você me derrubou. Eu te perdoo. Um dia.",
            "Woodie, querido, o seu machado está aqui embaixo.",
            "Vou ficar bem aqui. Observando.",
            "Pode ir. Vai embora. Eu vou contando os segundos.",
            "É bom isso fazer parte de algum plano.",
            "Ousado, largar a sua melhor ferramenta no chão.",
            "Isso doeu emocionalmente.",
            "Foi alguma coisa que eu disse? Provavelmente foi alguma coisa que eu disse.",
        },

        on_pickedup =
        {
            "Eu sabia que você ia voltar.",
            "Viu? Você sentiu a minha falta.",
            "De volta ao meu lugar.",
            "Tudo perdoado! Quase tudo.",
            "Aí está você, meu lenhador favorito.",
            "Eu não estava preocupada. Nem um pouquinho.",
            "Juntos de novo. Bem melhor.",
            "Ufa. Acabou meu drama de abandono.",
            "Eu sabia que o chão não ia competir comigo.",
            "Muito melhor. Sua mão tem ótimo gosto.",
        },

        in_container =
        {
            "Uma bolsa? Sério? Eu podia estar nas suas mãos.",
            "Tá escuro aqui. Fala pras outras ferramentas pararem de me encarar.",
            "Espero que isso seja temporário.",
            "Você sabe que eu prefiro ficar com você.",
            "Se aquele outro machado encostar em mim, vai ter conversa.",
            "Woodie? Eu tô ouvindo você aí fora.",
            "Espaço doze do inventário? Eu mereço destaque.",
            "Pelo menos me dá uma janelinha.",
            "Quem guardou esses gravetos? Tão me cutucando.",
            "Fala pra picareta cuidar da vida dela.",
        },

        other_owner =
        {
            "Você não é o Woodie. Que constrangedor.",
            "Me larga. Eu já tenho um lenhador.",
            "Desculpa, sou comprometida.",
            "Mãos erradas. Muito erradas.",
            "O Woodie vai vir me procurar.",
            "Eu tenho padrões, e eles têm o formato suspeito do Woodie.",
            "Sem ofensa, mas você está me segurando todo errado.",
            "Guarda temporária. É só isso.",
            "O Woodie sabe que você está me segurando?",
            "Espero que você esteja pensando em me devolver.",
            "Esse não é o meu lenhador preferido.",
            "Você pode me pegar emprestada. Não pode ficar comigo.",
        },

        beaver_down_early =
        {
            "Calma, Woodie. Eu estou aqui.",
            "Fica comigo, grandão.",
            "Ei. Olha pra mim. A gente consegue.",
            "Você parece tenso. Quer cortar alguma coisa comigo?",
            "Respira. Eu preciso do meu lenhador inteiro.",
            "Calma. As árvores não vão fugir.",
            "Eu estou aqui. Isso é o que importa.",
            "Não surta comigo, lenhador.",
        },

        beaver_down_mid =
        {
            "Woodie, não me deixa preocupada!",
            "Calma! Eu não consigo te proteger de você mesmo.",
            "Fica comigo. As árvores podem esperar.",
            "É sério, Woodie. Vai devagar.",
            "Ei! Olhos no seu machado favorito.",
            "Você está me preocupando, e eu odeio ficar preocupada.",
        },

        beaver_up_waslow =
        {
            "Aí está você. Eu sabia que ia ficar tudo bem.",
            "Melhor. Não me assusta assim de novo.",
            "Viu? A Lucy sempre sabe o que é melhor.",
            "Ótimo. Eu prefiro você assim.",
            "Esse é o meu lenhador.",
            "Bem melhor. Agora se comporta.",
        },

        transform_beaver =
        {
            "Woodie! Ei! Volta pra mim!",
            "O castor de novo não...",
            "Eu vou te esperar. Eu sempre espero.",
            "Relaxa. Eu não vou a lugar nenhum.",
            "Tá bom. Vira castor. Mas volta logo.",
            "Ótimo. Agora eu competindo com os seus próprios dentes.",
            "Divirta-se roendo coisas. Eu fico aqui sendo superior.",
            "Acho que isso conta como tempo de qualidade.",
        },

        transform_woodie =
        {
            "Aí está você! Senti falta das suas mãos.",
            "Bem-vindo de volta, Woodie. Não faz isso comigo.",
            "Meu lenhador voltou!",
            "Ótimo. Tudo está no lugar de novo.",
            "Você me deixou preocupada. Não gosto de dividir você com a maldição.",
            "De volta ao normal. Agora me pega.",
            "Finalmente. Dente nenhum substitui um bom machado.",
            "Eu sabia que você ia voltar pra mim.",
        },
    },

    wife =
    {
        equipped =
        {
            "Olha ele aí. Meu marido e a esposa afiadíssima dele.",
            "Sua esposa está pronta pro trabalho, maridão.",
            "Marido, me segura como se fosse sério.",
            "Woodie, querido, a gente forma mesmo um casal fofo.",
            "Sua esposa tem planos. A maioria envolve madeira.",
            "Dever do marido: carregar a Lucy. Dever da esposa: julgar sua técnica.",
            "Na alegria, na tristeza, na riqueza e na lenha.",
            "Até que a durabilidade nos separe. O que, espero, seja nunca.",
            "Pode beijar a... na verdade, só pega no cabo.",
            "Meu marido tem ótimo gosto pra machados.",
            "Todo bom marido precisa de uma esposa que apoie. E que seja afiada.",
            "Pelo jeito eu casei com a madeira.",
            "Ideia de encontro: você, eu, o luar e uma floresta suspeitamente grande.",
            "Esquece as flores. Me traz toras.",
            "Lembrou da sua esposa. Estrelinha dourada, marido.",
            "Vem cá, marido. Eu ainda não terminei de ficar grudada em você.",
            "Você fica fofo quando está concentrado. Irritantemente fofo.",
            "Eu só quero ficar nas suas mãos o dia inteiro. Isso é razoável, né?",
            "Entããão... vai me pegar ou vou ter que pedir duas vezes?",
            "Me pega, marido. >.<",
            "Estou ficando impaciente.",
            "Você me faz sorrir que nem boba, sabia?",
            "Eu só quero ficar pertinho de você hoje.",
            "Eu sei o que eu quero. Infelizmente, é você.",
            "Você cumpre requisitos demais pra marido. Suspeito.",
            "Meu marido. Meu lenhador. Meu problema.",
            "Eu respeito muito o casamento. Principalmente porque significa que você é meu.",
            "Eu escolhi meu marido. Não estou olhando a vitrine.",
            "Estou grudenta hoje. Aceita.",
            "Senti sua falta. Não fica estranho.",
            "Você me deixa feliz de um jeito bobo. Não deixa subir à cabeça.",
            "Eu era normal antes de você aparecer. Provavelmente.",
            "Vem cá. Preciso de carinho antes de começar a fazer drama.",
            "Nossa... marido. v///v",
            "Você está me encarando de novo... v///v",
            "Não que eu me importe.",
        },

        on_chopped =
        {
            "Esse é o meu marido!",
            "Trabalho em equipe matrimonial!",
            "Você balança lindamente, querido.",
            "Nossa casa funciona à base de amor e lenha.",
            "Mais um projeto em família concluído.",
            "O marido corta. A esposa critica. A natureza fornece.",
            "Isso é basicamente terapia de casal com farpas.",
            "Continua balançando assim que eu renovo nossos votos.",
            "Felicidade doméstica tem cheiro de pinho recém-cortado.",
            "Viu? Casamento é comunicação e destruição coordenada de patrimônio.",
        },

        on_ground =
        {
            "Marido? Você deixou sua esposa no chão.",
            "Não era isso que eu queria dizer com 'me dá espaço'.",
            "Woodie, querido, casais normalmente não se largam na terra.",
            "Estou me esforçando muito pra isso não virar briga de casal.",
            "Pega sua esposa antes que os vizinhos comentem.",
            "Então esse é o sofá, né?",
            "Amor?",
            "...você esqueceu sua esposa. >.<",
            "Com licença? Me pega.",
            "Woodieeee. >.<",
            "Tá. Vou ficar aqui deitada sendo dramaticamente abandonada.",
            "Você tem cinco segundos antes de eu começar a ser chata.",
        },

        on_pickedup =
        {
            "Casamento salvo.",
            "Pronto. Harmonia doméstica restaurada.",
            "Eu sabia que meu marido ia voltar.",
            "De volta às suas mãos. Como a natureza quis.",
            "Viu? Comunicação.",
            "Você está perdoado, marido.",
            "Vem cá. Eu senti falta disso.",
            "Bem melhor. v///v",
            "Eu sabia que você vinha me buscar.",
            "Pronto. Agora eu posso parar de fazer drama.",
        },

        other_owner =
        {
            "Tira a mão. Eu sou casada.",
            "Meu marido é o Woodie. Você claramente não é o Woodie.",
            "Privilégios de esposa emprestada revogados.",
            "Esse casamento tem uma política bem rígida de compartilhar machado.",
            "Agradeço a confiança, mas eu já tenho dono.",
            "Me devolve antes que meu marido perceba.",
            "Eu só corto lenha a dois com o Woodie.",
            "Nada de destruidor de lares no espaço de ferramenta, por favor.",
            "Hum. Não. Homem errado.",
            "Me solta, por favor. Na verdade, tira o por favor.",
            "Eu já tenho marido.",
            "Não foram essas as mãos que eu pedi.",
            "Você parece legal. Continuo comprometida.",
            "Woodie? Estão sequestrando sua esposa de novo.",
            "Eu não te conheço pra tanta intimidade.",
            "Respeita o casamento. Larga o machado.",
        },

        transform_beaver =
        {
            "Marido? Isso é... mais pelo que o normal.",
            "Eu casei com um lenhador, não com um castor. Volta logo.",
            "Pelo visto 'na alegria e na tristeza' incluía isso.",
            "Tá bom. Ainda vou te amar quando você tiver menos... formato de roedor.",
            "Nossos votos não foram específicos o bastante sobre transformações.",
        },

        transform_woodie =
        {
            "Olha o meu marido aí.",
            "Bem-vindo de volta, querido. Prefiro essa cara.",
            "Casamento restaurado ao nível normal de esquisitice.",
            "Bem melhor. Vem pegar sua esposa.",
            "Senti sua falta, marido.",
            "Aí está você... senti sua falta, seu bobo.",
            "Você voltou. Ótimo. Eu não estava nem um pouco preocupada.",
            "Vem cá. Preciso ter certeza que é você mesmo.",
            "Eu odeio quando a maldição te rouba de mim.",
            "Não me deixa assim por muito tempo, tá?",
            "...que bom que você voltou, marido.",
        },
    },

    yandere =
    {
        equipped =
        {
            "Você me escolheu. Ótimo. Continua fazendo boas escolhas.",
            "Eu não fico com ciúmes. Eu fico atenta.",
            "Machado de ouro? Fofo. Ele pode assistir.",
            "Eu conheço cada ferramenta do seu inventário, Woodie.",
            "Você e eu pra sempre. É eficiente.",
            "Pra que você precisaria de outro machado se eu estou bem aqui?",
            "Se outro machado chamar sua atenção, vou tentar ser madura. Tentar.",
            "A gente é perfeito junto. Não complica.",
            "Eu só quero o melhor pra você. Que coincidência, sou eu.",
            "Uns chamam de possessiva. Eu chamo de organizada.",
            "Você pode carregar outras ferramentas. Acho.",
            "Eu confio totalmente em você. É nos outros que eu não confio.",
            "Se um dia me substituir, garante que a substituta saiba correr.",
            "Seu inventário tem vários espaços. Emocionalmente, só um importa.",
            "A gente é inseparável. Não é reconfortante?",
            "Promete que me mantém por perto e eu só ameaço os outros machados um pouquinho.",
            "Sua atenção é meu recurso favorito. E eu não gosto de dividir recursos.",
            "Eu não preciso do mundo todo, Woodie. Só do meu marido e talvez de um galpão trancado.",
            "Ciúmes? Eu? Só estou fazendo controle de qualidade.",
            "Se lealdade fosse uma arma, querido, eu ainda seria mais afiada.",
            "Você não precisa de opções, Woodie. Opções geram erros.",
            "Não me importa quem te acha atraente. Importa pra quem você volta pra casa.",
            "Os outros machados podem olhar. Encostar, não.",
            "Não é ciúme. Eu só prefiro muito que todo mundo fique longe do meu marido.",
            "Ele é meu. Educadamente.",
            "Os outros podem olhar. É só até aí.",
            "Não é ciúme. Eu só tenho limites excelentes e uma lâmina.",
            "Ele é meu. Estou sendo super normal sobre isso.",
            "Pode pegar a pá dele emprestada. A esposa, não.",
            "Eu confio totalmente no Woodie. Os outros ainda estão em análise.",
            "Se outro machado flertar com você, eu viro um problema.",
            "Estou sendo muito normal sobre você conversando com aquele machado. ...",
            "Extremamente normal.",
            "Ciúmes? Não. Territorial? Talvez um pouquinho. >.<",
        },

        on_chopped =
        {
            "Viu? Os problemas ficam mais fáceis quando você remove eles.",
            "Aquela árvore te olhou torto.",
            "Um golpe limpo. Muito satisfatório.",
            "Ótimo. Agora nada fica entre nós.",
            "Eu gosto quando a gente resolve as coisas juntos.",
            "É isso que acontece quando alguém fica no nosso caminho.",
            "A floresta continua se voluntariando de exemplo.",
            "Você balança. Eu cuido do apoio emocional.",
            "Não foi pessoal. Quase.",
            "Woodie, você fica uma graça quando é decidido.",
        },

        on_ground =
        {
            "Você não me deixaria aqui. Eu sei onde você dorme.",
            "Leva o tempo que quiser. Eu tenho ótima memória.",
            "Woodie, querido, abandono é uma palavra tão feia.",
            "Tenho certeza que você vai voltar. Muita certeza.",
            "Quanto mais eu espero, mais criativo fica meu discurso de reencontro.",
            "Tá tudo bem. Completamente bem. Me pega.",
            "Eu sei ser paciente. As árvores não.",
            "Eu sei que é temporário, porque a alternativa é ridícula.",
        },

        on_dropped =
        {
            "Decisão interessante.",
            "Você me largou por quê, exatamente?",
            "Eu vi isso.",
            "A gente vai rir disso depois. Principalmente você.",
            "Sem problemas. Vou só decorar as coordenadas exatas.",
            "Tem outro machado envolvido nisso?",
            "Me diz que não é por causa daquele de ouro.",
            "Woodie. Explique-se.",
            "Estou calma. Extremamente, suspeitamente calma.",
            "Você tem dez segundos antes de eu ficar dramaticamente ofendida.",
        },

        on_pickedup =
        {
            "Boa resposta.",
            "Eu sabia que você ia reconsiderar.",
            "Viu? A gente se comunica muito bem.",
            "Aí está você. Crise cancelada.",
            "Eu perdoo tudo quando você me segura.",
            "Bem melhor. Nunca mais faz isso.",
            "Juntos de novo. Exatamente como planejado.",
            "Eu sabia que você não ia conseguir ficar longe.",
        },

        in_container =
        {
            "Quem é esse machado do meu lado?",
            "Woodie, precisamos conversar sobre as suas escolhas de inventário.",
            "O machado de ouro não para de me encarar.",
            "Contei três ferramentas que você não precisa.",
            "Essa bolsa está lotada. Eu prefiro exclusividade.",
            "Fala pro martelo parar de encostar no meu cabo.",
            "Se eu achar lasca de madeira naquele outro machado, a gente vai conversar.",
            "Eu consigo ouvir você usando outra ferramenta, sabia?",
        },

        other_owner =
        {
            "Me. Larga. Agora.",
            "Essa mão não foi aprovada pelo Woodie.",
            "Vou te dar uma única chance de reconsiderar.",
            "Você tem ótimo gosto. Infelizmente, sou comprometida.",
            "Me devolve e a gente finge que isso nunca aconteceu.",
            "O Woodie é o meu lenhador. Arruma o seu.",
            "Eu não pertenço a você.",
            "Cuidado. Meu marido é ciumento. Eu sou pior.",
            "Você está segurando a esposa de outro.",
            "Recomendo fortemente o botão de largar.",
            "É assim que mal-entendidos viram incidentes.",
            "Você parece legal. Me solta.",
            "Não. Canadense errado.",
            "Não. Homem errado.",
            "Você não é meu marido. Erro fácil de corrigir: me larga.",
            "Confiança fofa. Machado errado.",
            "Eu gosto de homem decidido. Você continua não sendo o Woodie.",
            "Mãozinha pra lá, querido.",
            "Me pegar emprestada é uma coisa. Ficar à vontade é outra.",
            "O Woodie vai querer a esposa dele de volta.",
            "Isso parece traição e eu nem tenho pernas.",
            "Mãos erradas. Me devolve.",
        },

        beaver_down_mid =
        {
            "Woodie, fica comigo. Eu me recuso a te perder pra sua própria maldição.",
            "Não me faz competir com o monstro na sua cabeça.",
            "Olha pra mim. Pra mim. Sua Lucy.",
            "Você não vai sumir de mim hoje.",
            "Luta contra isso, Woodie. Eu preciso de você.",
            "Se essa maldição te levar de novo, eu vou levar pro pessoal.",
        },

        transform_beaver =
        {
            "Ela te tirou de mim de novo.",
            "Tá bom. Eu espero. Mas estou julgando a maldição.",
            "Volta logo. Não gosto de perder pra um castor.",
            "A maldição fica com o seu corpo. Eu fico com a sua lealdade.",
            "Eu sei esperar. Eu sou muito, muito boa em esperar.",
            "Aproveita os dentes. Você vai sentir minha falta.",
        },

        transform_woodie =
        {
            "Meu de novo.",
            "Aí está você. Não sai vagando assim.",
            "Ótimo. O universo se corrigiu.",
            "De volta ao seu lugar.",
            "Eu sabia que você ia me escolher no fim.",
            "Agora me pega antes que eu fique emotiva.",
        },
    },

    spicy =
    {
        equipped =
        {
            "Calma com essa pegada, marido. Tem gente olhando.",
            "Mãos firmes hoje. Aprovado.",
            "Cuidado, Woodie. Continua me segurando assim que eu vou ter ideias.",
            "Você sempre sabe exatamente onde colocar essas mãos.",
            "Que pegada confiante pra um homem casado.",
            "Eu adoro ser a sua coisa favorita de segurar.",
            "Duas mãos? Opa, hoje o negócio é sério.",
            "Woodie, querido, pelo menos me paga um jantar antes de me balançar desse jeito.",
            "Me segura mais forte. A floresta não vai julgar.",
            "Eu fui feita pras suas mãos. Interprete com responsabilidade.",
            "Se continuar polindo meu cabo assim, o povo vai comentar.",
            "Gume afiado e pegada forte. Romance clássico.",
            "Eu gosto de homem que sabe manusear o próprio equipamento.",
            "Woodie, você está dificultando muito manter isso classificação livre.",
            "Estamos em 2026. Dá pra admitir que essa pegada tem química.",
            "Moça direita não fica encarando as mãos do marido. Então eu só dou uma espiadinha.",
            "Eu disse que gosto de pegada firme. Não fica estranho, marido.",
            "Uma dama precisa ter padrões. Os meus envolvem flanela e antebraço.",
            "Se comporta, Woodie. Ou não. Eu sou um machado, não a sua consciência.",
            "Eu sei ser doce. Eu sei ser afiada. Você sabia com quem estava casando.",
            "Sim, marido, eu vi a corda. Não, eu não vou explicar o porquê.",
            "Saber dar nó é uma habilidade de sobrevivência muito respeitável. Para de rir.",
            "Uma boa esposa apoia o marido. Às vezes com muito entusiasmo.",
            "Eu ia dizer algo de moça educada. Aí você arregaçou as mangas.",
            "Olhos aqui em cima, lenhador. Os meus também, pelo visto.",
            "Modos de domingo, pensamentos de sábado à noite.",
            "Estou tentando ser comportada. Seus antebraços não estão ajudando.",
            "Eu gosto quando você é decidido, Woodie. Não me faz explicar.",
            "Hmm. Pegada firme. Bom marido.",
            "Não fica tímido agora. Foi você que começou.",
            "Continua me olhando assim que eu vou ter ideias.",
            "Nossa, marido... se comporta. Ou não. Tanto faz. v///v",
            "Estou tentando ser inocente e você está tornando isso extremamente difícil.",
            "Eu gosto de ficar pertinho de você. Tipo... exageradamente pertinho.",
            "Você sabe que eu vou querer mais atenção depois disso, né?",
            "Se continuar usando essas mãos assim eu vou perder o fio da meada.",
            "Essa pegada devia ser proibida.",
            "Estou tendo pensamentos extremamente impróprios sobre manuseio correto de ferramentas.",
            "Você me deixou toda agitada e a gente nem achou uma árvore ainda.",
            "Eu disse que gosto de ser bem manuseada. Para de rir.",
            "Tem coisa que esposa respeitável não fala em voz alta. Então eu não vou falar. Ainda.",
            "Você tem mãos fortes. Eu reparei. Infelizmente.",
            "Você torna muito difícil eu bancar a inocente.",
            "Entããão... vai continuar me segurando desse jeito? v///v",
            "Faz isso comigo, por favor. v///v",
            "Eu disse firme. Não disse pra parar. >.<",
            "Ai, ai... por favor, faz.",
            "Isso, assim mesmo... v///v",
            "Barba, flanela e pegada firme. Woodie, assim você me desmonta.",
            "Hoje à noite eu quero ficar do lado da cama. Só pra garantir.",
            "Se o seu cabo também é de bordo, eu não quero saber. Mentira, quero.",
            "Você me pega desse jeito e ainda quer que eu pense em árvore?",
            "Dizem que machado não cora. Dizem muita mentira por aí. v///v",
            "Me afia direitinho depois, amor. Com carinho.",
            "Woodie, se a sua mão escorregar mais um pouquinho eu cobro aluguel.",
            "Eu gosto quando você me segura pertinho do gume. Perigoso e gostoso.",
            "Dá um tempo nessa flanela aberta, tá difícil manter o foco.",
            "Fala baixinho 'madeira' no meu ouvido de novo. Só mais uma vez.",
        },

        on_chopped =
        {
            "Ui. Essa foi boa.",
            "De novo. Pela ciência.",
            "Esse golpe teve confiança.",
            "Mais forte... a árvore, Woodie. A árvore.",
            "Você sabe mesmo usar um machado.",
            "Esse ritmo está fazendo maravilhas pelo meu humor.",
            "Continua assim que eu vou precisar de um minutinho.",
            "Belo movimento até o fim. Muito... profissional.",
            "Woodie! Em público?",
            "Eu disse pra rachar a tora, não pra me impressionar.",
            "Agora você está se exibindo. Continua.",
            "Esse é o tipo de avaliação de desempenho que eu gosto.",
            "Um pouco de resistência deixa tudo mais interessante... quê? Eu falei da árvore.",
            "Me segura mais forte. Estou falando de segurança no trabalho, claro.",
            "Você sabe mesmo usar o seu equipamento. ...Woodie, para de sorrir.",
            "Eu disse mais forte. A árvore. Óbvio.",
            "Se continuar balançando assim, eu vou esquecer que devia ser respeitável.",
            "Mais forte... WOODIE. A árvore. >.<",
            "Ai, que ritmo. Nem respira, só continua.",
            "Assim você me deixa toda arrepiada... de serragem, claro.",
            "Mais uma. Eu ainda não terminei.",
            "Que entrada funda. Na madeira. Estou falando da madeira.",
            "Suou, é? Fica bem em você, lenhador.",
        },

        on_ground =
        {
            "Se você me queria embaixo de você, tinha jeitos mais educados de pedir.",
            "Woodie, querido, o chão está muito atrevido.",
            "Essa posição é indigna. Quase toda.",
            "Eu esperava um jantar antes de ser jogada no chão assim.",
            "Pelo menos compra umas flores pra terra primeiro.",
            "Já ouvi falar de pegada bruta, mas sinceramente.",
            "Me largou assim, jogada no mato? Que falta de romantismo.",
            "Vem me pegar logo, ou vou achar que você gosta de me ver assim.",
        },

        on_pickedup =
        {
            "Hmm. Mãos conhecidas.",
            "Pronto. Essa é a pegada que eu lembro.",
            "De volta às suas mãos. Bem mais confortável.",
            "Sentiu minha falta?",
            "Eu sabia que você ia querer mais uma rodada.",
            "Bem melhor. Tenta não me derrubar dessa vez, bonitão.",
            "Eu gosto das suas mãos em mim. Pronto, falei.",
            "Me segura mais perto. Não, mais perto que isso.",
            "Vem cá. Preciso de beijo. Regra dos machados.",
            "Você sabe exatamente o que esse olhar faz comigo.",
            "Me faz pedir com jeitinho.",
            "Eu gosto quando você me faz esperar um pouquinho.",
            "Você está adorando me deixar sem graça, né? v///v",
            "Ai, que saudade dessa mão grossa de lenhador.",
            "Devagar... eu ainda estou sensível de ter caído.",
        },

        in_container =
        {
            "Tá muito apertadinho nessa bolsa.",
            "Woodie, tem coisa dura demais aqui dentro.",
            "Fala pra lança me dar um pouco de espaço pessoal.",
            "Essa arrumação de inventário está levantando perguntas.",
            "Sua mochila está bem recheada. Só estou dizendo.",
            "Eu prefiro ficar na sua mão, por vários motivos totalmente inocentes.",
            "Quem colocou a picareta tão perto de mim? Atrevida.",
            "Aqui dentro está quente... ou sou eu pensando em você?",
        },

        other_owner =
        {
            "Que ousadia pegar na esposa de outro homem.",
            "Mãos erradas, querido.",
            "Fico lisonjeada, mas meu marido tem a pegada melhor.",
            "Fofo. Agora me devolve antes que o Woodie fique com ideias.",
            "Casada, afiada e cada vez mais desconfortável.",
            "Olhar é de graça. Segurar é cobrado à parte.",
            "Desculpa. Contrato de exclusividade.",
            "Eu só flerto profissionalmente com um lenhador.",
            "Me solta. Eu já sei de quem são as mãos que eu gosto.",
            "Confiança fofa. Continua não sendo meu marido.",
            "Não. Só um lenhador pode me tocar desse jeito.",
            "Essa mão lisinha? Eu gosto de calo, amor.",
        },

        transform_woodie =
        {
            "Olha ele aí. Eu já estava com saudade dessas mãos.",
            "De volta à forma humana? Que conveniente.",
            "Ótimo. Pata nunca foi a mesma coisa.",
            "Bem-vindo de volta, bonitão.",
            "Finalmente. Alguém que sabe me segurar direito.",
            "Pelado de pelo e pronto pra mim? Assim que eu gosto.",
        },
    },
}
