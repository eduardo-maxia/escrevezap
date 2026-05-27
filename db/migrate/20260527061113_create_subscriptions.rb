class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "inactive"
      t.string :plan, null: false, default: "basic"
      t.string :abacatepay_subscription_id
      t.string :abacatepay_customer_id
      t.string :abacatepay_checkout_url
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_ends_at
      t.datetime :cancelled_at

      t.timestamps
    end
    add_index :subscriptions, :abacatepay_subscription_id, unique: true, where: "abacatepay_subscription_id IS NOT NULL"
  end
end
