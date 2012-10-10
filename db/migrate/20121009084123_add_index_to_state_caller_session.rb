class AddIndexToStateCallerSession < ActiveRecord::Migration
  def change
    add_index :caller_sessions, [:state], :name => "index_state_caller_sessions"
  end
end
