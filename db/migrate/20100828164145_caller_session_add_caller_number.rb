class CallerSessionAddCallerNumber < ActiveRecord::Migration
  def self.up
    add_column :caller_sessions, :caller_number, :string
    add_column :campaigns, :caller_id, :string
    add_column :campaigns, :caller_id_verified, :boolean, :default=>false
  end

  def self.down
    remove_column :campaigns, :caller_id_verified
    remove_column :campaigns, :caller_id
    remove_column :caller_sessions, :caller_number
  end
end
