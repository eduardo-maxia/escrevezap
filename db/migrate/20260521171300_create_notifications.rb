class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # Polymorphic association to the sender (e.g., Chip, EmailService)
      t.references :sender, polymorphic: true
      
      t.string :event_type # message, email, call
      t.string :notification_status # pending, sent, failed, whatsapp ACK
      t.string :external_id # ID from external service (e.g., Waha message ID)

      t.datetime :scheduled_at # When the notification is scheduled to be sent
      t.datetime :sent_at # When the notification was actually sent

      t.text :payload # Store the content of the notification (e.g., message text, email body)
      
      t.references :campaign_client, foreign_key: true
      t.references :installment, foreign_key: true

      t.timestamps
    end
  end
end
