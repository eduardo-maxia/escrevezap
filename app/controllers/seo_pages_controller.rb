class SeoPagesController < ApplicationController
  layout "landing"

  # Each entry powers a full SEO landing page that converts to the same
  # CTA as the homepage. To add a new keyword landing, add an entry here
  # and a route in `config/routes.rb`. The shared template handles render.
  PAGES = {
    "transcrever-audio-whatsapp" => {
      keyword:     "transcrever áudio do WhatsApp",
      title:       "Transcrever Áudio do WhatsApp em Texto Automaticamente",
      description: "Transcreva áudios do WhatsApp em texto automaticamente, com IA. Conecte sua conta, escolha os contatos e leia cada mensagem de voz em segundos.",
      h1:          "Transcrever áudio do WhatsApp em texto",
      intro:       "O EscreveZap transcreve automaticamente os áudios que você recebe (ou envia) no WhatsApp e devolve o texto direto na conversa — sem trocar de app, sem copiar e colar, sem precisar dar play.",
      benefits: [
        { icon: "ph-lightning",      title: "Transcrição em segundos",     body: "Cada áudio é convertido em texto assim que chega na conversa." },
        { icon: "ph-brain",          title: "IA otimizada para PT-BR",     body: "Pontuação, gírias e formatação pensadas para o português brasileiro." },
        { icon: "ph-whatsapp-logo",  title: "Funciona no seu WhatsApp",    body: "Sem número novo, sem trocar de app. Use sua conta de sempre." },
        { icon: "ph-users-three",    title: "Escolha por contato",          body: "Decida quais conversas quer transcrever — e só elas." }
      ],
      steps: [
        "Conecte seu WhatsApp ao EscreveZap escaneando um QR Code.",
        "Escolha os contatos cujos áudios você quer transcrever.",
        "Pronto: a transcrição aparece como resposta na própria conversa."
      ],
      faqs: [
        {
          question: "Como transcrever áudio do WhatsApp em texto sem instalar nada?",
          answer:   "Com o EscreveZap você conecta sua conta do WhatsApp via QR Code, como faz no WhatsApp Web. A partir daí, os áudios são transcritos automaticamente sem precisar instalar app, plugin ou extensão."
        },
        {
          question: "A transcrição funciona com áudios antigos?",
          answer:   "O EscreveZap transcreve áudios novos recebidos a partir do momento em que você conecta a conta. Áudios antigos do histórico não são transcritos retroativamente."
        },
        {
          question: "Os áudios são privados?",
          answer:   "Sim. Os áudios são processados de forma segura e descartados após a transcrição. Não armazenamos os arquivos de voz."
        }
      ]
    },

    "converter-audio-em-texto" => {
      keyword:     "converter áudio em texto",
      title:       "Converter Áudio em Texto Online — Com IA, Direto no WhatsApp",
      description: "Converta áudio em texto online com IA. EscreveZap transforma mensagens de voz do WhatsApp em texto formatado e responde direto na conversa.",
      h1:          "Converter áudio em texto com IA",
      intro:       "Não precisa baixar app de transcrição, fazer upload manual ou colar áudio em outra ferramenta. O EscreveZap converte áudio em texto diretamente dentro do WhatsApp, em tempo real.",
      benefits: [
        { icon: "ph-microphone",      title: "Voz em texto na hora",        body: "Cada mensagem de voz vira texto em segundos." },
        { icon: "ph-sparkle",         title: "Formatação inteligente",      body: "Pontuação, parágrafos e até resumo automático no plano Pro." },
        { icon: "ph-shield-check",    title: "Privado por padrão",          body: "Áudios processados com segurança e descartados em seguida." },
        { icon: "ph-arrows-clockwise", title: "Funciona 24/7",                body: "Não importa a hora — o áudio chega já transcrito." }
      ],
      steps: [
        "Cadastre-se grátis em segundos.",
        "Conecte seu WhatsApp e escolha os contatos.",
        "Receba o áudio convertido em texto, direto na conversa."
      ],
      faqs: [
        {
          question: "Como converter um áudio em texto sem digitar manualmente?",
          answer:   "Você só precisa ter o áudio chegando no WhatsApp. Com o EscreveZap conectado, o sistema converte automaticamente — você nunca precisa digitar nada."
        },
        {
          question: "Funciona com áudios longos?",
          answer:   "Sim. O EscreveZap transcreve áudios de qualquer duração suportada pelo WhatsApp e, no plano Pro, ainda gera um resumo curto para você ler primeiro."
        }
      ]
    },

    "responder-audio-whatsapp" => {
      keyword:     "responder áudio do WhatsApp",
      title:       "Responder Áudio do WhatsApp Sem Precisar Ouvir | EscreveZap",
      description: "Responda áudios do WhatsApp sem precisar ouvir. O EscreveZap transcreve cada mensagem de voz em texto na hora, para você ler e responder de qualquer lugar.",
      h1:          "Responder áudio do WhatsApp sem precisar ouvir",
      intro:       "Em reunião, no trabalho, no transporte público ou em qualquer lugar onde não dá para tocar o áudio: leia a mensagem em texto e responda imediatamente, sem perder o contexto.",
      benefits: [
        { icon: "ph-chat-text",       title: "Leia em vez de ouvir",        body: "O áudio chega já como texto na própria conversa." },
        { icon: "ph-headphones",      title: "Sem fone, sem problema",      body: "Não precisa de fone, silêncio ou privacidade." },
        { icon: "ph-clock-counter-clockwise", title: "Sem voltar 5 vezes", body: "Áudios longos viram texto escaneável e com resumo." },
        { icon: "ph-eye",             title: "Respeita sua atenção",         body: "Bata o olho, entenda o contexto, responda." }
      ],
      steps: [
        "Conecte seu WhatsApp no EscreveZap.",
        "Marque os contatos que mais te mandam áudio.",
        "Da próxima vez que chegar um áudio, você lê em texto antes de tocar."
      ],
      faqs: [
        {
          question: "Como responder áudio do WhatsApp sem dar play?",
          answer:   "Com a transcrição automática do EscreveZap, o áudio chega já transcrito como uma resposta na conversa. Você lê o texto e responde por texto ou áudio sem nunca precisar tocar a mensagem original."
        },
        {
          question: "A pessoa que mandou o áudio sabe que estou usando o EscreveZap?",
          answer:   "Só se você quiser. A transcrição aparece para você no chat. Você decide se compartilha ou não com o remetente."
        }
      ]
    },

    "audio-whatsapp-texto" => {
      keyword:     "áudio do WhatsApp em texto",
      title:       "Áudio do WhatsApp em Texto — Transcrição Automática com IA",
      description: "Transforme áudio do WhatsApp em texto automaticamente. Transcrição com IA, resposta direta na conversa e foco em português brasileiro.",
      h1:          "Áudio do WhatsApp em texto, sem complicação",
      intro:       "Pare de perder tempo ouvindo áudios longos. O EscreveZap transforma cada mensagem de voz do WhatsApp em texto inteligente, com pontuação e formatação automática.",
      benefits: [
        { icon: "ph-translate",       title: "Português brasileiro nativo", body: "Modelo otimizado para o jeito que a gente fala no Brasil." },
        { icon: "ph-article",         title: "Resumo + transcrição",         body: "No Pro, você recebe o ponto principal antes do texto completo." },
        { icon: "ph-link",            title: "Sem mudar nada no WhatsApp",   body: "Continua usando o app como sempre." },
        { icon: "ph-check-circle",    title: "Configure em 2 minutos",        body: "Cadastro, QR Code e pronto. Sem instalação." }
      ],
      steps: [
        "Crie sua conta grátis.",
        "Vincule seu WhatsApp ao EscreveZap.",
        "Receba cada áudio do WhatsApp em texto, automaticamente."
      ],
      faqs: [
        {
          question: "Dá pra transformar áudio do WhatsApp em texto de graça?",
          answer:   "Sim. O EscreveZap tem um plano gratuito com 20 transcrições por mês — perfeito para experimentar."
        },
        {
          question: "Posso transcrever áudios de grupos?",
          answer:   "O EscreveZap foca em conversas individuais com os contatos que você escolher. Para grupos, fique atento às novidades em breve."
        }
      ]
    },

    "como-transcrever-audio-de-cliente" => {
      keyword:     "transcrever áudio de cliente no WhatsApp",
      title:       "Como Transcrever Áudio de Cliente no WhatsApp | EscreveZap",
      description: "Transcreva automaticamente os áudios longos dos seus clientes no WhatsApp. Economize tempo, responda mais rápido e mantenha um histórico escrito do que foi pedido.",
      h1:          "Transcrever áudio de cliente no WhatsApp",
      intro:       "Atender clientes pelo WhatsApp é ótimo, até chegar aquele áudio de 4 minutos. Com o EscreveZap, os áudios dos seus clientes viram texto na hora. Leia o pedido, entenda o contexto e responda com agilidade.",
      benefits: [
        { icon: "ph-clock-user",      title: "Responda mais rápido",        body: "Leia em segundos o que levaria minutos para ouvir." },
        { icon: "ph-file-text",       title: "Histórico pesquisável",       body: "Tenha os pedidos dos clientes por escrito na conversa." },
        { icon: "ph-briefcase",       title: "Profissionalismo",            body: "Atenda o cliente mesmo em reuniões ou locais barulhentos." },
        { icon: "ph-check-circle",    title: "Sem instalar nada",           body: "Funciona direto no seu WhatsApp profissional ou pessoal." }
      ],
      steps: [
        "Crie sua conta no EscreveZap.",
        "Conecte seu WhatsApp e ative a transcrição para seus clientes.",
        "Leia os pedidos em texto sempre que receber um áudio."
      ],
      faqs: [
        {
          question: "Meus clientes vão saber que estou transcrevendo?",
          answer:   "Não. A transcrição aparece apenas no seu WhatsApp como uma resposta. Para o cliente, nada muda."
        },
        {
          question: "Funciona no WhatsApp Business?",
          answer:   "Sim. O EscreveZap conecta normalmente tanto no WhatsApp comum quanto no WhatsApp Business."
        }
      ]
    },

    "como-transcrever-audio-de-reuniao" => {
      keyword:     "transcrever áudio de reunião",
      title:       "Como Transcrever Áudio de Reunião no WhatsApp",
      description: "Converta gravações e áudios de reuniões no WhatsApp em texto automaticamente. Gere atas, resumos e encontre informações rapidamente com o EscreveZap.",
      h1:          "Transcrever áudio de reunião no WhatsApp",
      intro:       "Alguém mandou o áudio daquela reunião importante? Não perca tempo transcrevendo manualmente. O EscreveZap transforma o áudio em texto formatado, e nosso plano Pro até resume os pontos principais para você.",
      benefits: [
        { icon: "ph-list-bullets",    title: "Geração de Atas",             body: "Transforme áudios longos em texto para suas atas e relatórios." },
        { icon: "ph-sparkle",         title: "Resumo Automático (Pro)",     body: "A IA destaca os pontos mais importantes da reunião." },
        { icon: "ph-users",           title: "Foco no Trabalho",            body: "Poupe horas de digitação e revisão." },
        { icon: "ph-lock-key",        title: "Confidencialidade",           body: "Os áudios são descartados logo após a transcrição." }
      ],
      steps: [
        "Vincule sua conta ao EscreveZap.",
        "Receba ou envie o áudio da reunião no WhatsApp.",
        "O texto completo e o resumo aparecerão diretamente na conversa."
      ],
      faqs: [
        {
          question: "A IA consegue resumir uma reunião inteira?",
          answer:   "Sim. No plano Pro, nossa inteligência artificial lê toda a transcrição e gera um resumo executivo com os principais pontos discutidos."
        }
      ]
    },

    "como-transcrever-audio-de-corretor" => {
      keyword:     "transcrever áudio de corretor",
      title:       "Transcrever Áudio de Corretor de Imóveis | EscreveZap",
      description: "Corretores recebem e enviam muitos áudios. Transcreva detalhes de imóveis, negociações e propostas no WhatsApp para nunca perder informações cruciais.",
      h1:          "Transcrever áudios de negociação imobiliária",
      intro:       "Para o corretor de imóveis, informação é tudo. Transforme áudios de clientes e proprietários em texto. Nunca mais esqueça o valor de uma proposta ou os detalhes de uma visita.",
      benefits: [
        { icon: "ph-house-line",      title: "Detalhes do Imóvel",          body: "Leia metragens, valores e condições direto na tela." },
        { icon: "ph-handshake",       title: "Negociação Ágil",             body: "Responda clientes mais rápido lendo em vez de ouvindo." },
        { icon: "ph-magnifying-glass",title: "Busca Facilitada",            body: "Encontre informações de áudios passados pela pesquisa do WhatsApp." },
        { icon: "ph-car",             title: "Em Trânsito",                 body: "Leia rapidamente o resumo do áudio entre uma visita e outra." }
      ],
      steps: [
        "Conecte seu WhatsApp Business ou Pessoal.",
        "Reaja a um áudio com qualquer emoji (ou configure no automático).",
        "Pronto! A transcrição detalhada chega na hora."
      ],
      faqs: [
        {
          question: "Posso pesquisar a transcrição no WhatsApp depois?",
          answer:   "Sim! Como a transcrição é enviada como mensagem de texto na própria conversa, você pode usar a busca do WhatsApp para encontrar valores ou detalhes citados no áudio."
        }
      ]
    },

    "como-transcrever-audio-de-advogado" => {
      keyword:     "transcrever áudio de advogado",
      title:       "Transcrever Áudio Jurídico e de Clientes para Advogados",
      description: "Ferramenta essencial para advogados: transcreva áudios de clientes e colegas de forma segura e rápida diretamente no WhatsApp.",
      h1:          "Transcrição de áudios no WhatsApp para Advogados",
      intro:       "Advogados lidam com informações complexas e precisam de tudo documentado. O EscreveZap converte áudios do WhatsApp em texto com precisão, ajudando a organizar o atendimento e o andamento processual.",
      benefits: [
        { icon: "ph-scales",          title: "Precisão",                    body: "Transcrição fiel do que o cliente relatou." },
        { icon: "ph-shield",          title: "Sigilo Profissional",         body: "Nenhum áudio é armazenado nos nossos servidores." },
        { icon: "ph-files",           title: "Documentação",                body: "Facilita copiar relatos para petições e peças." },
        { icon: "ph-clock",           title: "Ganhe Tempo",                 body: "Leia um áudio de 5 minutos em 30 segundos." }
      ],
      steps: [
        "Faça o cadastro e vincule seu número.",
        "Escolha transcrever contatos específicos ou reaja aos áudios.",
        "Copie e cole o texto transcrito diretamente em seus documentos."
      ],
      faqs: [
        {
          question: "O serviço é seguro para informações confidenciais?",
          answer:   "Sim. Priorizamos a segurança e privacidade. Os áudios são processados de forma transitória e excluídos imediatamente. Não guardamos log de conversas."
        }
      ]
    },

    "como-transcrever-audio-de-medico" => {
      keyword:     "transcrever áudio de médico",
      title:       "Transcrever Áudio de Pacientes e Médicos no WhatsApp",
      description: "Profissionais da saúde podem transcrever áudios de pacientes rapidamente. Otimize o atendimento via WhatsApp com o EscreveZap.",
      h1:          "Transcrição de áudios no WhatsApp para Saúde",
      intro:       "Para médicos, psicólogos e profissionais de saúde, organizar as informações dos pacientes é vital. Transforme relatos por voz em texto de forma instantânea para atualizar prontuários com mais facilidade.",
      benefits: [
        { icon: "ph-heartbeat",       title: "Agilidade no Atendimento",    body: "Leia sintomas e relatos antes mesmo de responder." },
        { icon: "ph-clipboard-text",  title: "Facilita Prontuários",        body: "Copie o relato do paciente direto para o sistema." },
        { icon: "ph-shield-plus",     title: "Segurança de Dados",          body: "Processamento seguro e efêmero das mensagens de voz." },
        { icon: "ph-brain",           title: "Resumo Clínico",              body: "Com a IA (plano Pro), tenha o ponto principal destacado." }
      ],
      steps: [
        "Vincule o WhatsApp da sua clínica ou consultório.",
        "Receba os áudios dos pacientes normalmente.",
        "Leia a transcrição e atenda de forma mais eficiente."
      ],
      faqs: [
        {
          question: "É possível transcrever termos médicos?",
          answer:   "Nossa inteligência artificial é baseada em modelos avançados que conseguem reconhecer a grande maioria dos termos técnicos e médicos com alta precisão."
        }
      ]
    },

    "como-transcrever-audio-de-professor" => {
      keyword:     "transcrever áudio de professor",
      title:       "Transcrever Áudios de Professores e Alunos | EscreveZap",
      description: "Professores e estudantes podem transcrever explicações, dúvidas e aulas em áudio no WhatsApp. Transforme voz em texto para estudar melhor.",
      h1:          "Áudios de aulas e alunos transcritos na hora",
      intro:       "Seja um professor tirando dúvidas ou um aluno recebendo uma explicação, áudios longos podem ser difíceis de revisar. O EscreveZap transforma explicações por voz em texto claro e formatado.",
      benefits: [
        { icon: "ph-student",         title: "Facilita o Estudo",           body: "Tenha explicações em texto para revisar depois." },
        { icon: "ph-chalkboard-teacher", title: "Atendimento Rápido",       body: "Professores podem ler dúvidas de vários alunos rapidamente." },
        { icon: "ph-text-align-left", title: "Formatação Correta",          body: "Textos com pontuação para melhor compreensão." },
        { icon: "ph-share-network",   title: "Fácil de Compartilhar",       body: "Encaminhe o texto da explicação para outros grupos." }
      ],
      steps: [
        "Conecte seu WhatsApp ao EscreveZap.",
        "Sempre que receber um áudio longo, veja a transcrição aparecer.",
        "Use o texto para organizar seu material de estudo ou aula."
      ],
      faqs: [
        {
          question: "Os alunos precisam ter o app?",
          answer:   "Não, apenas quem deseja ler a transcrição precisa vincular o WhatsApp ao EscreveZap. O remetente envia o áudio normalmente."
        }
      ]
    },

    "escrevezap-vs-transcricao-whatsapp" => {
      keyword:     "transcrição nativa do WhatsApp",
      title:       "EscreveZap vs Transcrição Nativa do WhatsApp",
      description: "A transcrição do WhatsApp não está funcionando direito? Conheça o EscreveZap, a alternativa com IA avançada, resumos e melhor formatação para português.",
      h1:          "A Melhor Alternativa à Transcrição do WhatsApp",
      intro:       "Muitos usuários relatam que a transcrição nativa do WhatsApp falha, demora ou tem erros básicos em português. O EscreveZap usa inteligência artificial avançada para garantir um texto preciso, pontuado e até resumido.",
      benefits: [
        { icon: "ph-brain",           title: "IA Superior",                 body: "Entende gírias, sotaques e contexto melhor que a nativa." },
        { icon: "ph-article",         title: "Resumos (Pro)",               body: "Além do texto, você ganha um resumo em tópicos." },
        { icon: "ph-whatsapp-logo",   title: "100% Integrado",              body: "Funciona como uma resposta na própria conversa." },
        { icon: "ph-check-square-offset", title: "Confiável",               body: "Sem as instabilidades frequentemente relatadas no recurso nativo." }
      ],
      steps: [
        "Desative (se quiser) a transcrição nativa falha.",
        "Conecte seu número no EscreveZap.",
        "Reaja com um emoji ou configure contatos automáticos para transcrever com alta qualidade."
      ],
      faqs: [
        {
          question: "Por que usar o EscreveZap se o WhatsApp já tem transcrição?",
          answer:   "A transcrição nativa do WhatsApp costuma falhar em áudios longos, com ruído ou sotaques fortes. O EscreveZap usa modelos de IA dedicados de ponta, além de oferecer formatação superior e resumos automáticos."
        }
      ]
    },

    "transcricao-whatsapp-nao-funciona" => {
      keyword:     "transcrição do WhatsApp não funciona",
      title:       "Transcrição do WhatsApp Não Funciona? Tente o EscreveZap",
      description: "A transcrição de áudio do WhatsApp parou de funcionar? Descubra o EscreveZap, um serviço robusto e estável para converter voz em texto sem erros.",
      h1:          "Transcrição do WhatsApp parou de funcionar?",
      intro:       "Se a transcrição oficial do WhatsApp travou, não apareceu ou gerou um texto confuso, você não está sozinho. O EscreveZap é a solução definitiva e independente para quem precisa de transcrições que realmente funcionam.",
      benefits: [
        { icon: "ph-activity",        title: "Alta Disponibilidade",        body: "Sistemas robustos que não dependem da liberação gradual do WhatsApp." },
        { icon: "ph-magic-wand",      title: "Correção de Contexto",        body: "Nossa IA corrige o texto para fazer sentido." },
        { icon: "ph-smiley-nervous",  title: "Fim da Frustração",           body: "Sem mensagens de 'Não foi possível transcrever'." },
        { icon: "ph-device-mobile",   title: "Compatibilidade Total",       body: "Funciona no iOS, Android e no Web/Desktop." }
      ],
      steps: [
        "Acesse o EscreveZap e conecte sua conta.",
        "Volte para o seu WhatsApp e teste um áudio.",
        "Receba a transcrição instantânea com nossa IA avançada."
      ],
      faqs: [
        {
          question: "A transcrição do EscreveZap é mais rápida?",
          answer:   "Nossos servidores processam áudios em segundos. A resposta aparece diretamente no chat com fluidez e formatação impecável."
        }
      ]
    },

    "transcricao-whatsapp-web" => {
      keyword:     "transcrição no WhatsApp Web",
      title:       "Transcrição de Áudio no WhatsApp Web | EscreveZap",
      description: "Como transcrever áudios direto no WhatsApp Web pelo computador. Leia mensagens de voz no trabalho sem precisar pegar o celular.",
      h1:          "Transcrição de áudio perfeita no WhatsApp Web",
      intro:       "Está trabalhando no computador com o WhatsApp Web aberto e chega um áudio? Dar play nem sempre é uma opção. Com o EscreveZap, o texto do áudio aparece na tela do seu computador automaticamente.",
      benefits: [
        { icon: "ph-desktop",         title: "Foco no Trabalho",            body: "Não tire as mãos do teclado nem pegue o celular." },
        { icon: "ph-eye-slash",       title: "Discrição",                   body: "Ninguém no escritório vai saber o que te mandaram." },
        { icon: "ph-copy",            title: "Fácil de Copiar",             body: "Copie o texto transcrito pelo computador com um clique." },
        { icon: "ph-laptop",          title: "Funciona no Desktop",         body: "Integração transparente via WhatsApp sem instalar software." }
      ],
      steps: [
        "Faça login no EscreveZap pelo seu navegador.",
        "Escaneie o QR Code para conectar sua conta.",
        "Use o WhatsApp Web normalmente e leia os áudios que receber."
      ],
      faqs: [
        {
          question: "Preciso de alguma extensão do Chrome?",
          answer:   "Não! O EscreveZap não é uma extensão de navegador. Ele conecta diretamente à sua conta, o que o torna mais seguro e funciona até se o seu celular estiver desligado."
        }
      ]
    }
  }.freeze

  def show
    @page = PAGES[params[:slug]]
    return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless @page

    @slug = params[:slug]

    render :show
  end

  # Used by the dynamic sitemap to enumerate every SEO page.
  def self.slugs
    PAGES.keys
  end
end
