class CreateWahaSessionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :waha_session_events do |t|
      t.references :waha_session, null: false, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end
  end
end
