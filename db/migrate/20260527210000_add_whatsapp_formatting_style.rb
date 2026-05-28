class AddWhatsappFormattingStyle < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :formatting_style, from: "polished", to: "whatsapp"
  end

  def down
    change_column_default :users, :formatting_style, from: "whatsapp", to: "polished"
  end
end
