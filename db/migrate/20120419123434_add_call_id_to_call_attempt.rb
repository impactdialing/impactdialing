class AddCallIdToCallAttempt < ActiveRecord::Migration
  def self.up
    add_column(:call_attempts, :call_id, :integer)
  end

  def self.down
    remove_column(:call_attempts, :call_id)
  end
end
