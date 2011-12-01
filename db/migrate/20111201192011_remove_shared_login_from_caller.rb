class RemoveSharedLoginFromCaller < ActiveRecord::Migration
  def self.up
    remove_column :callers, :multi_user
  end

  def self.down
    add_column :callers, :multi_user, :boolean
    remove_column :callers, :multi_user
  end
 
end
