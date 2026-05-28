# Centralised, SEO-friendly content used by both the homepage view
# and the JSON-LD `FAQPage` schema. Keeping it in one place avoids
# drift between the rendered HTML and the structured data.
module HomeContent
  module_function

  FAQS = [
    {
      question: "Como transcrever áudio do WhatsApp em texto?",
      answer:   "Conecte seu WhatsApp ao EscreveZap escaneando um QR Code, escolha os contatos que você quer monitorar e pronto: todo áudio recebido é transcrito automaticamente em texto e a transcrição aparece como resposta na própria conversa do WhatsApp."
    },
    {
      question: "Isso usa meu próprio WhatsApp?",
      answer:   "Sim. Você conecta sua conta pessoal via QR Code. O EscreveZap funciona como um app vinculado ao seu WhatsApp, sem criar um número novo e sem precisar trocar o seu."
    },
    {
      question: "Preciso trocar de número de telefone?",
      answer:   "Não. Você usa exatamente o mesmo número que já tem. Nenhuma mudança é visível para os seus contatos."
    },
    {
      question: "Posso escolher quais contatos serão transcritos?",
      answer:   "Sim. Você seleciona cada contato individualmente. E para cada um você define se transcreve só os áudios que você manda, só os que recebe, ou ambos."
    },
    {
      question: "Como funciona o resumo inteligente dos áudios?",
      answer:   "No plano Pro, uma inteligência artificial lê a transcrição completa e produz um resumo curto com os pontos principais do áudio. É perfeito para mensagens de voz longas ou áudios com muita informação."
    },
    {
      question: "Meus áudios e conversas são privados?",
      answer:   "Sim. Os áudios são processados de forma segura e não são armazenados após a transcrição. Sua conversa do WhatsApp continua sendo sua."
    },
    {
      question: "Quanto custa para transcrever áudios do WhatsApp?",
      answer:   "Você pode começar de graça com 20 transcrições por mês. O plano Basic custa R$ 5,99/mês com 500 transcrições e o plano Pro custa R$ 19,90/mês com 2.000 transcrições e resumo com IA."
    },
    {
      question: "Posso cancelar quando quiser?",
      answer:   "Sim. Sem fidelidade e sem burocracia. Você cancela a qualquer momento e continua usando até o fim do período já pago."
    }
  ].freeze

  USE_CASES = [
    { emoji: "💼", title: "Em reunião",            body: "Áudio chega na hora errada. Leia o resumo em segundos sem sair da reunião." },
    { emoji: "🚗", title: "No trânsito",           body: "Não pode ouvir nem responder. Receba a transcrição e veja com calma depois." },
    { emoji: "🏢", title: "No trabalho",           body: "Sem fone, sem som, sem privacidade. Leia em vez de ouvir." },
    { emoji: "🎧", title: "Sem fone de ouvido",    body: "Não tem como ouvir sem incomodar quem está do lado." },
    { emoji: "📍", title: "Em lugar barulhento",   body: "Não consegue entender o áudio nem com volume máximo." },
    { emoji: "🤫", title: "Em silêncio",           body: "Bebê dormindo, biblioteca, hospital. A mensagem não pode esperar." },
    { emoji: "♿", title: "Acessibilidade",         body: "Quem tem perda auditiva consegue acompanhar todas as mensagens de voz." },
    { emoji: "⚡", title: "Com pressa",            body: "3 minutos de áudio. Você tem 20 segundos. Leia o resumo." }
  ].freeze

  COMPARISON_ROWS = [
    { feature: "Transcrição automática de áudios", whatsapp: false, escrevezap: true },
    { feature: "Resposta direto na conversa",       whatsapp: false, escrevezap: true },
    { feature: "Resumo do áudio com IA",            whatsapp: false, escrevezap: true },
    { feature: "Funciona com vários contatos",      whatsapp: false, escrevezap: true },
    { feature: "Escolher contatos específicos",     whatsapp: false, escrevezap: true },
    { feature: "Usar o seu próprio número",         whatsapp: true,  escrevezap: true },
    { feature: "Mensagens de voz nativas",          whatsapp: true,  escrevezap: true }
  ].freeze
end
