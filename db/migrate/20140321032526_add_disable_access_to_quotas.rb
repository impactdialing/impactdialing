class AddDisableAccessToQuotas < ActiveRecord::Migration
  def change
    add_column :quotas, :disable_access, :boolean
  end
end
