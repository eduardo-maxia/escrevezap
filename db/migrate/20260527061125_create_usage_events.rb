class CreateUsageEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :usage_events, [:user_id, :occurred_at]
    add_index :usage_events, :event_type
  end
end
