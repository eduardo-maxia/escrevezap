class AddPendingPlanToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :pending_plan, :string
  end
end
