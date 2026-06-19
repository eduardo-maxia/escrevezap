class Webhook::InterController < WebhookController
  def create
    log_info "Recebendo webhook da Inter"

    ExternalEvent.create!(
      provider: :inter,
      data: params[:inter].as_json
    ).enqueue_processing

    render json: { message: "Webhook recebido com sucesso" }
  end
end
