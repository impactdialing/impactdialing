class AddAllStatesToCall < ActiveRecord::Migration
  def self.up
    add_column(:calls, :all_states, :text)
  end

  def self.down
    remove_column(:calls, :all_states)
  end
end
