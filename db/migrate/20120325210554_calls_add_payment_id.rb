class CallsAddPaymentId < ActiveRecord::Migration
  def self.up
    add_column :caller_sessions, :payment_id, :integer
    add_column :call_attempts, :payment_id, :integer
  end

  def self.down
    remove_column :caller_sessions, :payment_id
    remove_column :call_attempts, :payment_id
  end
end