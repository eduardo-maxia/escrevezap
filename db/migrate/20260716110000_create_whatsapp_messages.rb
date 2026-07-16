class CreateWhatsappMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_messages do |t|
      t.references :user, null: true, foreign_key: true
      t.string :phone, null: false
      t.string :from, null: false
      t.string :to, null: false
      t.string :message_id
      t.string :direction, null: false
      t.string :message_type, null: false, default: "text"
      t.text :body, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :sent_at

      t.timestamps
    end

    add_index :whatsapp_messages, :phone
    add_index :whatsapp_messages, :direction
    add_index :whatsapp_messages, :message_type
    add_index :whatsapp_messages, :sent_at
    add_index :whatsapp_messages, :message_id
    add_index :whatsapp_messages, [ :user_id, :created_at ]
  end
end