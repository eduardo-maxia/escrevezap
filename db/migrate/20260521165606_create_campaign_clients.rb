class CreateCampaignClients < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_clients do |t|
      t.references :campaign, foreign_key: true
      t.references :client, foreign_key: true

      t.decimal :amount, precision: 10, scale: 2 # Pra o caso de ser uma mensalidade

      t.date :next_due_date # Para controlar a recorrência e saber quando enviar a próxima notificação

      t.string :status

      t.timestamps
    end
  end
end
