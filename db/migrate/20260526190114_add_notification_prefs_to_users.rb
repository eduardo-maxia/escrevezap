class AddNotificationPrefsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notif_proof_attached, :boolean, default: true, null: false
    add_column :users, :notif_chip_disconnected, :boolean, default: true, null: false
  end
end
