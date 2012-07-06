class AddActiveModeratorsIndex < ActiveRecord::Migration
  def self.up
    add_index(:moderators, [:session,:active])
  end

  def self.down
  end
end
