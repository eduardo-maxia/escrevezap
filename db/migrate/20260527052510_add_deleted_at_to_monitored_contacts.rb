class AddDeletedAtToMonitoredContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :monitored_contacts, :deleted_at, :datetime
    add_index :monitored_contacts, :deleted_at
  end
end
