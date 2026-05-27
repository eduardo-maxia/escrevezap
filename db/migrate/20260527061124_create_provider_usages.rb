class CreateProviderUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_usages do |t|
      t.references :transcription, null: false, foreign_key: true
      t.string :provider, null: false
      t.float :cost_usd, null: false, default: 0.0
      t.float :units
      t.string :unit_type
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
  end
end
