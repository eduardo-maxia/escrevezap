module Inter
  class WebhookProcessor
    include Loggable

    def initialize(payload:)
      @payload = payload
    end

    def call
      log_info "Processando webhook do Banco Inter..."
      
      parsed = ParseWebhook.new(payload: @payload).parse
      
      if parsed[:event_type] == "pix_received"
        handle_pix_received(parsed)
      else
        log_info "Evento desconhecido/não suportado: #{parsed[:event_type]}"
      end
    end

    private

    def handle_pix_received(data)
      tx_id = data[:tx_id]
      id_rec = data[:id_recorrencia]
      
      log_info "PIX recebido - tx_id: #{tx_id}, idRecorrencia: #{id_rec}, valor: R$ #{data[:amount]}"

      # Tentar encontrar Subscription por idRecorrencia (renovação automática) ou por tx_id (primeiro pagamento)
      subscription = nil
      if id_rec.present?
        subscription = Subscription.find_by(inter_recorrencia_id: id_rec)
      end
      
      if subscription.nil? && tx_id.present?
        subscription = Subscription.find_by(inter_txid: tx_id)
      end

      if subscription.nil?
        log_error "Nenhuma assinatura encontrada para o tx_id: #{tx_id} ou idRecorrencia: #{id_rec}."
        return
      end

      user = subscription.user
      plan = subscription.plan || "basic"
      
      # Atualizar/Ativar a assinatura
      subscription.update!(
        status: :active,
        inter_recorrencia_id: id_rec.presence || subscription.inter_recorrencia_id,
        current_period_start: Time.current,
        current_period_end: 1.month.from_now,
        trial_ends_at: nil,
        cancelled_at: nil
      )
      
      user.update!(plan: plan)
      log_info "Assinatura do usuário #{user.id} ativada/renovada com sucesso! Plano: #{plan}"

      # Notificar o usuário via WhatsApp
      if user.provider == "phone" && user.uid.present?
        begin
          plan_name = plan.to_s.humanize
          Meta::Service.new(recipient: user.uid).send_message(
            "🎉 *Pagamento Confirmado!*\n\n" \
            "Deu tudo certo! Sua assinatura do plano *#{plan_name}* via Pix Automático está ativa.\n\n" \
            "Seu limite de transcrições foi atualizado e você já pode voltar a transcrever seus áudios normalmente. " \
            "Muito obrigado pela confiança! 🚀"
          )
        rescue => e
          log_error "Erro ao enviar notificação de Pix para WhatsApp: #{e.message}"
        end
      end
    end
  end
end
