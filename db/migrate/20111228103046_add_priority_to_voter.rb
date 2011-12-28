class AddPriorityToVoter < ActiveRecord::Migration
  def self.up
    add_column :voters, :priority, :string
  end

  def self.down
    remove_column :voters, :priority
  end
end
