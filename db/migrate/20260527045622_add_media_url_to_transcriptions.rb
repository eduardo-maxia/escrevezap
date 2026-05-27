class AddMediaUrlToTranscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :transcriptions, :media_url, :text
  end
end
