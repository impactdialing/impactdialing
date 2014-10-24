class AddBlockedNumberIdToVoters < ActiveRecord::Migration
  def change
    add_column :voters, :blocked_number_id, :integer
    add_index :voters, :blocked_number_id, name: 'index_on_blocked_number_id'
  end
end
