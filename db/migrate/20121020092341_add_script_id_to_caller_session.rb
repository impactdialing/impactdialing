class AddScriptIdToCallerSession < ActiveRecord::Migration
  def change
    add_column :caller_sessions, :script_id, :integer
  end
end
