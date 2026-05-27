class CreateMonitoredContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :monitored_contacts do |t|
      t.references :waha_session, null: false, foreign_key: true

      t.string  :phone_number, null: false   # E.164, e.g. "5511999999999"
      t.string  :waha_chat_id               # e.g. "5511999999999@c.us"
      t.string  :display_name
      t.string  :avatar_url

      # Which direction to transcribe: incoming / outgoing / both
      t.string  :direction, null: false, default: "both"
      t.boolean :enabled,   null: false, default: true

      t.timestamps
    end

    add_index :monitored_contacts, [:waha_session_id, :phone_number], unique: true
    add_index :monitored_contacts, :waha_chat_id
  end
end
