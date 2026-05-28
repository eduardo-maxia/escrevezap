class AddAutoTranscribeToWahaSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :waha_sessions, :auto_transcribe, :string, null: false, default: "never"
    add_index  :waha_sessions, :auto_transcribe
  end
end
