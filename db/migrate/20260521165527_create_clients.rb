class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name
      t.string :phone_number
      t.string :waha_chat_id
      t.string :email
      t.references :company, foreign_key: true
      t.timestamps
    end
  end
end
