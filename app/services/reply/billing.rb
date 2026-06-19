module Reply
  module Billing
    private

    def show_billing
      plan = @user.plan
      limit = @user.transcription_limit
      used = @session.monthly_transcription_count

      plan_name = case plan.to_s
      when "basic" then "Basic"
      when "pro" then "Pro"
      else "Grátis"
      end

      renewal_date = if @user.subscription&.active_or_trialing? && @user.subscription.current_period_end.present?
                       @user.subscription.current_period_end
      else
                       Time.current.next_month.beginning_of_month
      end

      days_left = (renewal_date.to_date - Date.current).to_i
      days_left = 0 if days_left < 0

      days_label = days_left == 1 ? "falta 1 dia" : "faltam #{days_left} dias"

      billing_text = <<~MSG
        💳 *Seu Plano & Uso*

        *   *Plano Atual:* #{plan_name}
        *   *Uso este mês:* #{used} de #{limit} transcrições.
        *   *Renovação:* #{renewal_date.strftime("%d/%m/%Y")} (_#{days_label}_)
      MSG

      send_message(message: billing_text)
      sleep 0.5.seconds

      rows = []
      rows << { id: "upgrade_basic", title: "Assinar Basic (R$5,99)", description: "500 transcrições/mês" } if plan != "basic"
      rows << { id: "upgrade_pro", title: "Assinar Pro (R$19,90)", description: "2.000 transcrições/mês + IA" } if plan != "pro"
      rows << { id: "cancel_subscription", title: "Cancelar Assinatura", description: "Voltar ao plano gratuito" } if @user.subscription&.active_or_trialing?
      rows << { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Voltar para o menu principal" }

      send_list_message(
        body_text: "Selecione uma das opções abaixo:",
        button_text: "Ver opções",
        sections: [
          {
            title: "Assinaturas & Upgrade",
            rows: rows
          }
        ]
      )
    end

    def generate_upgrade_checkout(plan)
      send_message(message: "⏳ *Gerando seu link de pagamento seguro...* Aguarde um momento.")

      product_id = case plan
      when "basic" then Rails.application.credentials.dig(:abacatepay, :product_basic_id)
      when "pro"   then Rails.application.credentials.dig(:abacatepay, :product_pro_id)
      end

      if product_id.blank?
        send_message(message: "⚠️ Desculpe, a assinatura para o plano #{plan.capitalize} está indisponível no momento. Tente novamente mais tarde.")
        show_billing
        return
      end

      external_id = "user_#{@user.id}:#{plan}:#{Time.current.to_i}"
      return_url = "https://wa.me/558296801867"

      response = Abacatepay::Client.new.subscriptions.create(
        product_id:     product_id,
        external_id:    external_id,
        completion_url: return_url,
        return_url:     return_url
      )

      if response["success"]
        checkout_url = response.dig("data", "url")
        body_text = <<~MSG
          ⚡ *Pronto! Seu link de pagamento foi gerado:*

          Clique no botão abaixo para concluir a assinatura do plano *#{plan.capitalize}*.

          Assim que a confirmação for recebida pelo nosso sistema, seu limite será atualizado na hora e eu te aviso aqui!
        MSG

        send_cta_url_message(
          body_text: body_text,
          button_text: "Realizar Pagamento ⚡",
          url: checkout_url
        )

        sleep 1.second

        send_list_message(
          body_text: "Você pode usar as opções abaixo para acompanhar sua assinatura ou pedir ajuda:",
          button_text: "Opções",
          sections: [
            {
              title: "Acompanhamento",
              rows: [
                { id: "menu_billing", title: "🔄 Já paguei", description: "Verificar se o plano já atualizou" },
                { id: "menu_support", title: "🚨 Dificuldade para pagar", description: "Falar com nosso suporte" },
                { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Voltar para o menu principal" }
              ]
            }
          ]
        )
      else
        error_msg = response["error"].presence || "Erro no checkout"
        Rails.logger.error "[Reply::Base#generate_upgrade_checkout] AbacatePay error: #{error_msg}"
        send_message(message: "⚠️ Não foi possível iniciar o checkout via Pix. Por favor, tente novamente.")
        sleep 0.5.seconds
        show_menu
      end
    end

    def process_subscription_cancellation
      subscription = @user.subscription

      unless subscription&.active_or_trialing?
        send_message(message: "⚠️ Você não possui uma assinatura ativa para cancelar.")
        show_billing
        return
      end

      response = Abacatepay::Client.new.subscriptions.cancel(
        id: subscription.abacatepay_subscription_id
      )

      if response["success"]
        subscription.update!(status: :cancelled, cancelled_at: Time.current)
        @user.update!(plan: :free)
        send_message(message: "🚫 Assinatura cancelada com sucesso. Você foi migrado de volta para o plano Grátis.")
      else
        Rails.logger.error "[Reply::Base#process_subscription_cancellation] AbacatePay error: #{response['error']}"
        send_message(message: "⚠️ Não foi possível processar o cancelamento automático. Por favor, entre em contato com nosso suporte pelo email ola@escrevezap.com.br")
      end

      sleep 0.5.seconds
      show_menu
    end
  end
end
