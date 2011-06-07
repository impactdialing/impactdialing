class AddIndexUserIdAndName < ActiveRecord::Migration
  def self.up
    add_index(:voter_lists, [:user_id, :name], :unique => true)
  end

  def self.down
  end
end
