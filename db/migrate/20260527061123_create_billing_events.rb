class CreateBillingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_events do |t|
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.boolean :processed, null: false, default: false
      t.datetime :processed_at

      t.timestamps
    end
    add_index :billing_events, :event_id, unique: true
  end
end
