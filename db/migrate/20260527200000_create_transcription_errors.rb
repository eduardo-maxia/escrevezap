class CreateTranscriptionErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :transcription_errors do |t|
      t.references :transcription, null: false, foreign_key: true, index: true
      t.string  :stage,       null: false
      t.string  :error_class, null: false
      t.text    :message,     null: false
      t.text    :backtrace

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :transcription_errors, [:transcription_id, :created_at]
    add_index :transcription_errors, :stage
  end
end
