class AddIndexToModeratorsActive < ActiveRecord::Migration
  def self.up
    add_index(:moderators, [:session,:active, :account_id, :created_at], :name => 'active_moderators')
  end

  def self.down
  end
end
