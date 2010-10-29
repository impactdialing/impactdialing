class CallAttemptAddCallEndIndex < ActiveRecord::Migration
  def self.up
    add_index(:call_attempts, :call_end)
  end

  def self.down
  end
end
