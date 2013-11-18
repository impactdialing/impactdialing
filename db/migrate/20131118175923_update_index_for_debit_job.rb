class UpdateIndexForDebitJob < ActiveRecord::Migration
  def up
    remove_index :caller_sessions, name: 'index_caller_session_debit'
    remove_index :call_attempts, name: "index_call_attempts_debit"
    add_index :call_attempts, [:debited, :status, :tStartTime, :tEndTime, :tDuration], name: 'index_call_attempts_debit'
    add_index :transfer_attempts, [:debited, :status, :tStartTime, :tEndTime, :tDuration], name: "index_transfer_attempts_debit"
    add_index :caller_sessions, [:debited, :caller_type, :tStartTime, :tEndTime, :tDuration], name: "index_caller_sessions_debit"
  end

  def down
    remove_index :transfer_attempts, name: 'index_transfer_attempts_debit'
    remove_index :caller_sessions, name: 'index_caller_sessions_debit'
    remove_index :call_attempts, name: 'index_call_attempts_debit'
    add_index :caller_sessions, [:type, :debited, :caller_type, :tEndTime], name: "index_caller_session_debit"
    add_index :call_attempts, [:debited, :tEndTime], :name => "index_call_attempts_debit"
  end
end
