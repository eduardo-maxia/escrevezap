class AddConversationStateToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :conversation_state, :jsonb, default: {}
  end
end
