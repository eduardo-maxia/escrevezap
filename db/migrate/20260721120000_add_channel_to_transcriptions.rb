class AddChannelToTranscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :transcriptions, :channel, :string, null: false, default: "waha"
    add_column :transcriptions, :media_id, :string
    add_index  :transcriptions, :channel
  end
end
