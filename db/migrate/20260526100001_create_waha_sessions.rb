class CreateWahaSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :waha_sessions do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :session_name, null: false
      t.string :waha_status,  null: false, default: "pending"
      t.string :waha_chat_id
      t.string :display_name
      t.string :avatar_url

      t.timestamps
    end

    add_index :waha_sessions, :session_name, unique: true
  end
end
