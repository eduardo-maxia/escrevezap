class CreateExternalEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :external_events do |t|
      t.string  :provider,      null: false, default: "waha"
      t.string  :status,        null: false, default: "pending"
      t.string  :event_type
      t.jsonb   :data,          null: false, default: {}
      t.jsonb   :parsed_event,  default: {}
      t.integer :retry_count,   null: false, default: 0
      t.text    :error_message

      t.timestamps
    end

    add_index :external_events, :status
    add_index :external_events, :provider
    add_index :external_events, :event_type
  end
end
