class AddTranscriptionModeToWahaSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :waha_sessions, :transcription_mode, :string, null: false, default: "reaction"
    add_index  :waha_sessions, :transcription_mode

    add_column :monitored_contacts, :auto_created, :boolean, null: false, default: false
    add_index  :monitored_contacts, :auto_created

    # Backfill: existing sessions that already have at least one monitored
    # contact should keep using the manual-contacts mode. Sessions without
    # any contacts default to the new "reaction" mode.
    execute <<~SQL
      UPDATE waha_sessions
      SET transcription_mode = 'monitored_contacts'
      WHERE id IN (
        SELECT DISTINCT waha_session_id
        FROM monitored_contacts
        WHERE deleted_at IS NULL
      )
    SQL
  end

  def down
    remove_index  :monitored_contacts, :auto_created
    remove_column :monitored_contacts, :auto_created

    remove_index  :waha_sessions, :transcription_mode
    remove_column :waha_sessions, :transcription_mode
  end
end
