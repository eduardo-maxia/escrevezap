class SendMessageJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.includes(campaign_client: :client).find(notification_id)

    # Rule 4: only send if the notification is still pending.
    unless notification.pending?
      Rails.logger.info "[SendMessageJob] notification=#{notification_id} skipped (status=#{notification.notification_status})"
      return
    end

    # Rule 4: cancel if the associated installment is no longer pending.
    if notification.installment.present? && !notification.installment.pending?
      notification.update_columns(
        notification_status: "cancelled",
        cancellation_reason: "Parcela com status '#{notification.installment.status}' no momento do envio",
        updated_at:          Time.current
      )
      return
    end

    chip   = notification.sender
    client = notification.campaign_client.client
    text   = notification.payload

    raise ArgumentError, "Notification #{notification_id} has no sender chip" unless chip.is_a?(Chip)
    raise ArgumentError, "Notification #{notification_id} has no message text" if text.blank?

    waha = Waha::Client.new(session: chip.waha_session)

    # Mark as sending
    notification.update!(notification_status: :sending)

    unless client.waha_chat_id.present?
      raise ArgumentError, "Client #{client.id} has no WhatsApp chat ID"
    end

    # Human-like send: read → typing → sleep → send
    # Não podemos marcar como lida porque se não o usuário final não recebe notificação!
    response = waha.messaging.send_text(chat_id: client.waha_chat_id, text: text)
    # response = waha.messaging.send_message(chat_id: client.waha_chat_id, text: text)

    notification.update!(notification_status: :sent, sent_at: Time.current, external_id: response["id"])

  rescue ApiRequest::ApiClientError, ApiRequest::ApiServerError,
         ApiRequest::ApiConnectionError => e
    Rails.logger.error "[SendMessageJob] notification=#{notification_id} error=#{e.message}"
    notification.update!(notification_status: :failed) if defined?(notification) && notification
  end
end
