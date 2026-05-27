class AddFormattingStyleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :formatting_style, :string, default: "polished", null: false
  end
end
