class CreateInstallments < ActiveRecord::Migration[8.1]
  def change
    create_table :installments do |t|
      t.date :due_date # For reference
      t.decimal :amount, precision: 10, scale: 2
      t.string :status # pending, paid, cancelled

      t.references :campaign_client, foreign_key: true

      t.timestamps
    end
  end
end
