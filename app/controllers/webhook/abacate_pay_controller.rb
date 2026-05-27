class Webhook::AbacatePayController < WebhookController
  # POST /webhook/abacate_pay?webhookSecret=SECRET
  def create
    # 1. Validate URL secret
    unless Abacatepay::WebhookVerifier.valid_secret?(request.query_parameters)
      Rails.logger.warn "[AbacatePayWebhook] Invalid webhook secret"
      head :unauthorized and return
    end

    # 2. Validate HMAC signature
    raw_body = request.body.read
    request.body.rewind
    unless Abacatepay::WebhookVerifier.valid_signature?(raw_body, request.headers["X-Webhook-Signature"])
      Rails.logger.warn "[AbacatePayWebhook] Invalid HMAC signature"
      head :unauthorized and return
    end

    event_id   = params[:id].to_s
    event_type = params[:event].to_s

    # 3. Idempotency — ignore already-processed events
    if BillingEvent.exists?(event_id: event_id)
      head :ok and return
    end

    billing_event = BillingEvent.create!(
      event_id:   event_id,
      event_type: event_type,
      payload:    params.to_unsafe_h
    )

    ProcessBillingEventJob.perform_later(billing_event.id)

    head :ok
  rescue => e
    Rails.logger.error "[AbacatePayWebhook] Unexpected error: #{e.message}"
    head :ok # Always 200 to prevent retries for our own bugs
  end
end
