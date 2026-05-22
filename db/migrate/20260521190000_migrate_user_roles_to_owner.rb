class MigrateUserRolesToOwner < ActiveRecord::Migration[8.1]
  def up
    # Users who went through onboarding and created their company are owners.
    # All existing company-linked users with no role get promoted to owner.
    execute <<~SQL
      UPDATE users SET role = 'owner' WHERE company_id IS NOT NULL AND (role IS NULL OR role = 'admin')
    SQL
  end

  def down
    execute <<~SQL
      UPDATE users SET role = 'admin' WHERE role = 'owner'
    SQL
  end
end
