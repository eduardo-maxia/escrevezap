class Webhook::WahaController < WebhookController
  def create
    log_info "Recebendo webhook do Waha, session: #{params[:session]}, event: #{params[:event]}"

    ExternalEvent.create!(
      provider: :waha,
      data: params[:waha].as_json
    ).enqueue_processing

    log_info "Resposta recebida com sucesso"

    render json: { message: 'Webhook recebido com sucesso' }
  end
end
