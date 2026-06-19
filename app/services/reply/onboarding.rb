module Reply
  module Onboarding
    private

    def show_menu
      if @user.onboarding_completed?
        send_main_menu
      else
        start_onboarding
      end
    end

    def start_onboarding
      first_message = "Oi *#{@display_name || 'Usuário'}*, seja bem-vindo ao EscreveZap! 👋"
      second_message = "Eu transcrevo áudios de WhatsApp de forma super simples, basta reagir com qualquer emoji ao áudio na própria conversa que eu gero a transcrição e mando lá mesmo!"

      send_message(message: first_message)
      sleep 0.5.seconds
      send_message(message: second_message)
      sleep 0.5.seconds

      send_list_message(
        body_text: "Para começar a usar, você só precisa conectar seu WhatsApp ao nosso servidor. Escolha uma opção:",
        button_text: "Ver opções",
        sections: [
          {
            title: "Introdução",
            rows: [
              { id: "onboarding_connect", title: "🔌 Conectar WhatsApp", description: "Conectar seu celular (Recomendado)" },
              { id: "onboarding_how", title: "❓ Como funciona?", description: "Ver instruções detalhadas de uso" },
              { id: "onboarding_plans", title: "💵 Planos e Preços", description: "Ver limites de transcrição e planos" }
            ]
          }
        ]
      )

      @current_conversation_state["stage"] = "initial"
    end

    def send_main_menu
      whatsapp_rows = [
        { id: "menu_status", title: "📡 Status da Conexão", description: "Verificar se seu celular está ativo" }
      ]

      if @session.working?
        whatsapp_rows << { id: "menu_disconnect_prompt", title: "🔌 Desconectar", description: "Desconectar seu WhatsApp" }
      else
        whatsapp_rows << { id: "menu_connect", title: "🔌 Conectar WhatsApp", description: "Gerar código de pareamento" }
      end

      send_list_message(
        body_text: "Como posso ajudar você hoje?",
        button_text: "Escolher opção",
        sections: [
          {
            title: "WhatsApp",
            rows: whatsapp_rows
          },
          {
            title: "Conta",
            rows: [
              { id: "menu_billing", title: "💳 Plano e Faturamento", description: "Ver limite, uso mensal e upgrades" },
              { id: "menu_help", title: "❓ Ajuda / Como usar", description: "Relembrar instruções de transcrição" }
            ]
          },
          {
            title: "Suporte",
            rows: [
              { id: "menu_support", title: "🚨 Falar com Suporte", description: "Contato do time Salva-Vidas" }
            ]
          }
        ],
        header_text: "Menu Principal - EscreveZap",
        footer_text: "EscreveZap"
      )
      @current_conversation_state["stage"] = "initial"
    end

    def show_how_it_works
      how_text = <<~MSG
        ❓ *Como funciona o EscreveZap?*

        1. Quando alguém te enviar um áudio (ou você enviar um), basta *reagir ao áudio com qualquer emoji* (ex: 👀, 👍, ❤️).
        2. Eu vou ler o áudio e em poucos segundos respondo no mesmo chat com a transcrição completa.

        Simples assim! Sem precisar abrir nenhum site ou painel. ⚡
      MSG
      # 3. Você também pode *encaminhar um áudio* para esta conversa comigo, e eu transcrevo ele aqui na hora!

      send_cta_url_message(
        body_text: how_text,
        button_text: "Acessar Site 🌐",
        url: "https://escrevezap.com.br"
      )
      sleep 0.5.seconds
      show_menu
    end

    def show_plans
      plans_text = <<~MSG
        💵 *Nossos Planos e Limites:*

        *1. Grátis (R$ 0)*
        - 20 transcrições por mês

        *2. Basic (R$ 5,99/mês)*
        - 500 transcrições por mês

        *3. Pro (R$ 19,90/mês)*
        - 2.000 transcrições por mês
        - Formatação inteligente com IA
      MSG

      send_message(message: plans_text)
      sleep 0.5.seconds
      show_menu
    end

    def show_support
      send_message(message: "Precisa de ajuda? Aqui está o contato do nosso time de suporte Salva-Vidas: 🧑‍🚒")
      send_contact(name: "Suporte EscreveZap", phone: "85921606104")
      sleep 0.5.seconds
      show_menu
    end
  end
end
