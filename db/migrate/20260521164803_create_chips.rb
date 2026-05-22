class CreateChips < ActiveRecord::Migration[8.1]
  def change
    create_table :chips do |t|
      t.string :name
      t.string :provider # Por enquanto fixo :waha
      
      t.string :waha_status
      t.string :waha_session
      t.string :waha_chat_id
      t.string :waha_worker

      t.references :company, foreign_key: true

      t.timestamps
    end
  end
end
