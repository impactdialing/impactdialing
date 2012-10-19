class AddIndexForDebitJob < ActiveRecord::Migration
  def up
    remove_index :call_attempts, name: 'index_call_attempts_on_debited_and_call_end'
    add_index :call_attempts, [:debited, :tEndTime], :name => "index_call_attempts_debit"
    add_index :caller_sessions, [:type, :debited, :caller_type, :tEndTime], :name => "index_caller_session_debit"    
  end

  def down
  end
end
