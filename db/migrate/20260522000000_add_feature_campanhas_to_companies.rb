class AddFeatureCampanhasToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :feature_campanhas, :boolean, default: false, null: false
  end
end
