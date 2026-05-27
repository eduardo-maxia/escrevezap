class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string   :email,              null: false
      t.string   :name
      t.boolean  :admin,              null: false, default: false
      t.string   :provider
      t.string   :uid
      t.string   :avatar_url
      t.integer  :sign_in_count,      null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.datetime :remember_created_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, [ :provider, :uid ], unique: true,
              where: "provider IS NOT NULL", name: "index_users_on_provider_uid"
  end
end
