class CampaginAddMaxcalls < ActiveRecord::Migration
  def self.up
    add_column :campaigns, :max_calls_per_caller, :integer, :default=>20
  end

  def self.down
    remove_column :campaigns, :max_calls_per_caller
  end
end
