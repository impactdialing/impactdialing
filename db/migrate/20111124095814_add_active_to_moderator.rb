class AddActiveToModerator < ActiveRecord::Migration
  def self.up
    add_column :moderators, :active, :string
  end

  def self.down
    remove_column :moderators, :active
  end
end
