class MoveBlockedNumbersToAccount < ActiveRecord::Migration
  def self.up
    rename_column :blocked_numbers, :user_id, :account_id
  end

  def self.down
    rename_column :blocked_numbers, :account_id, :user_id
  end
end
