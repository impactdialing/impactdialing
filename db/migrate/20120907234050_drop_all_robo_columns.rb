class DropAllRoboColumns < ActiveRecord::Migration
  def change
    drop_table :call_responses
    remove_column :campaigns, :robo
    remove_column :campaigns, :voicemail_script_id
    drop_table :delayed_jobs
    drop_table :robo_recordings
  end
end
