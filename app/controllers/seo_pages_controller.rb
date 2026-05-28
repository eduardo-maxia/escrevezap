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
    }
  }.freeze

  def show
    @page = PAGES[params[:slug]]
    return render file: Rails.public_path.join("404.html"), status: :not_found, layout: false unless @page

    @slug = params[:slug]
    content_for :title_full,  @page[:title]
    content_for :description, @page[:description]
    content_for :jsonld do
      faq_jsonld(@page[:faqs])
    end

    render :show
  end

  # Used by the dynamic sitemap to enumerate every SEO page.
  def self.slugs
    PAGES.keys
  end
end
