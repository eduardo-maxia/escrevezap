class Notification < ApplicationRecord
  belongs_to :campaign_client
  belongs_to :installment, optional: true
  belongs_to :sender, polymorphic: true

  enum :event_type, { message: "message", email: "email", call: "call" }
  enum :notification_status, {
    failed: "failed",     # -1
    pending: "pending",   # 0
    sent: "sent",         # 1
    delivered: "delivered", # 2
    read: "read",         # 3, 4
    sending: "sending",   # during sending process
    cancelled: "cancelled" # aborted before send
  }, default: :pending

  after_update_commit :broadcast_status_change, if: :saved_change_to_notification_status?

  private

  def broadcast_status_change
    ActionCable.server.broadcast(
      "notification_status_#{id}",
      { status: notification_status, sent_at: sent_at&.iso8601 }
    )
  end

  public

  def set_ack(new_ack)
    # Se o new_ack for string, faz a conversão
    new_ack = Notification.notification_statuses.keys.index(new_ack.to_s) - 1 if new_ack.is_a?(String)
    # Only accepts ack updates that are higher than the current ack (except for -1)
    # self.ack is a string, new_ack is an integer
    # First, get current ack as integer
    if new_ack == -1
      self.ack = :failed
      save!
      return
    end

    current_ack_value = Notification.notification_statuses.keys.index(self.notification_status || 'pending') - 1
    return if new_ack <= current_ack_value && self.notification_status != "sending"

    self.notification_status = Notification.notification_statuses.keys[new_ack + 1]
    save!
  end
end
