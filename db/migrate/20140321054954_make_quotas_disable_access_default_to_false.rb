class MakeQuotasDisableAccessDefaultToFalse < ActiveRecord::Migration
  def up
    change_column :quotas, :disable_access, :boolean, default: false
  end

  def down
    change_column :quotas, :disable_access, :boolean
  end
end
