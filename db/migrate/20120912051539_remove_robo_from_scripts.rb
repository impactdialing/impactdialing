class RemoveRoboFromScripts < ActiveRecord::Migration
  def change
    remove_column :scripts, :robo
    remove_column :scripts, :for_voicemail
  end
end
