class AddRoleCompanyToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    add_column :users, :role, :string
    add_reference :users, :company, foreign_key: true
  end
end
