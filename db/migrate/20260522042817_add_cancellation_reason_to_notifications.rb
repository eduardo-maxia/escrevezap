class AddCancellationReasonToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :cancellation_reason, :string
  end
end
