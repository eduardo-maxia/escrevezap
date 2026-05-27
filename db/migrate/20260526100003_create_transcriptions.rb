class CreateTranscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :transcriptions do |t|
      t.references :monitored_contact, null: false, foreign_key: true

      t.string :waha_message_id              # ID of the original audio message
      t.text   :transcript                   # Raw Deepgram output
      t.text   :summary                      # AI summary (Pro plan)
      t.text   :full_formatted               # AI-formatted transcript (Pro plan)

      t.string  :direction, null: false, default: "incoming"   # incoming / outgoing
      t.float   :audio_duration                                 # seconds
      t.string  :status,    null: false, default: "processing"  # processing / completed / failed

      t.string  :reply_message_id            # ID of the reply sent back
      t.text    :error_message

      t.timestamps
    end

    add_index :transcriptions, :waha_message_id
    add_index :transcriptions, :status
    add_index :transcriptions, [:monitored_contact_id, :created_at]
  end
end
