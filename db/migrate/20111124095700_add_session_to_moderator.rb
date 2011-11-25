class AddSessionToModerator < ActiveRecord::Migration
  def self.up
    add_column :moderators, :session, :string
  end

  def self.down
    remove_column :moderators, :session
  end
end
