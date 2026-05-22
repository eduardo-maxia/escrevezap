class MakeNotificationExternalIdAnIndex < ActiveRecord::Migration[8.1]
  def change
    # The unique index should be sender <> external_id, because different senders can have the same external_id
    add_index :notifications, [:sender_type, :sender_id, :external_id], unique: true
  end
end
