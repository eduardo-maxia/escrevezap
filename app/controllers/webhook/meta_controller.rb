class Webhook::MetaController < WebhookController
  def index
    render json: params["hub.challenge"]
  end

  def create
    log_info "Recebendo webhook da Meta"

    ExternalEvent.create!(
      provider: :meta,
      # event_id: params.dig("entry", 0, "id"),
      data: params.as_json
    ).enqueue_processing

    render json: { message: "Webhook recebido com sucesso" }
  end
end
