class AddAccountIdToCallerGroups < ActiveRecord::Migration
  def self.up
    add_column :caller_groups, :account_id, :integer, null: false
  end

  def self.down
    remove_column :caller_groups, :account_id
  end
end
