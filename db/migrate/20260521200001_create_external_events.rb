class CreateExternalEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :external_events do |t|
      t.string "provider"
      t.string "status"
      t.string "event_type"
      t.string "event_id"
      t.text "error_message"
      t.jsonb "data"
      t.jsonb "parsed_event"
      t.integer "retry_count"
      
      t.timestamps
    end
  end
end
