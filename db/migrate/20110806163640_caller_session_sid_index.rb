class CallerSessionSidIndex < ActiveRecord::Migration
  def self.up
    add_index(:caller_sessions, :sid)
  end

  def self.down
  end
end
