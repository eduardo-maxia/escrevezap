class AddContactsIntroDismissedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :contacts_intro_dismissed, :boolean, null: false, default: false
  end
end
