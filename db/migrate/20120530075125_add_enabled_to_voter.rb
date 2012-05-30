class AddEnabledToVoter < ActiveRecord::Migration
  def self.up
    add_column :voters, :enabled, :boolean, :default=>1
  end

  def self.down
    remove_column :voters, :enabled
  end
end
