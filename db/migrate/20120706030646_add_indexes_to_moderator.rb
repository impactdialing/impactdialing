class AddIndexesToModerator < ActiveRecord::Migration
  def self.up
    add_index(:moderators, [:active,:account_id,:created_at])
  end

  def self.down
  end
end
