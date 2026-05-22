class AddInactivatedAtToCampaignClients < ActiveRecord::Migration[8.1]
  def change
    add_column :campaign_clients, :inactivated_at, :datetime
  end
end
