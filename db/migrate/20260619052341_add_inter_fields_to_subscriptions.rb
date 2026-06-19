class AddInterFieldsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :provider, :string, default: "abacatepay", null: false
    add_column :subscriptions, :inter_recorrencia_id, :string
    add_column :subscriptions, :inter_txid, :string
    add_column :subscriptions, :payer_cpf, :string
    add_column :subscriptions, :payer_name, :string

    add_index :subscriptions, :inter_recorrencia_id, unique: true, where: "inter_recorrencia_id IS NOT NULL"
    add_index :subscriptions, :inter_txid, unique: true, where: "inter_txid IS NOT NULL"
  end
end
