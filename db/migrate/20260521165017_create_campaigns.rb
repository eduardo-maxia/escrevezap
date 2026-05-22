class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :name
      t.references :company, foreign_key: true
      t.references :chip, foreign_key: true

      t.jsonb :template

      t.string :recurrence_pattern # De início vai ser tudo monthly
      
      # Temos que ter horário de início e fim para a campanha (dentro do dia)
      t.time :start_time
      t.time :end_time

      t.string :status

      t.timestamps
    end
  end
end
