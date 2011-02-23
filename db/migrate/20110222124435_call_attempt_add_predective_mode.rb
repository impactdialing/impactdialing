class CallAttemptAddPredectiveMode < ActiveRecord::Migration
  def self.up
    add_column :call_attempts, :dialer_mode, :string
  end

  def self.down
    remove_column :call_attempts, :dialer_mode
  end
end