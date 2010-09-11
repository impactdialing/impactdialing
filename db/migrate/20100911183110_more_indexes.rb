class MoreIndexes < ActiveRecord::Migration
  def self.up
    add_index(:caller_sessions, :caller_id)
    add_index(:caller_sessions, :campaign_id)
    add_index(:voters, :campaign_id)
    add_index(:voters, :status)
  end

  def self.down
  end
end
