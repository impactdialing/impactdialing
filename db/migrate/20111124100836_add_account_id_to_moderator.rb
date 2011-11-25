class AddAccountIdToModerator < ActiveRecord::Migration
  def self.up
    add_column :moderators, :account_id, :integer
  end

  def self.down
    remove_column :moderators, :account_id
  end
end
