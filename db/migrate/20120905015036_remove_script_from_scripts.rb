class RemoveScriptFromScripts < ActiveRecord::Migration
  def change
    remove_column :scripts, :script
  end
end
