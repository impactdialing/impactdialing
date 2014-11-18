class ChangeVotersBlockedNumberIdToBlocked < ActiveRecord::Migration
  def up
    remove_index :voters, name: 'index_on_blocked_number_id'
    rename_column :voters, :blocked_number_id, :blocked
    change_column :voters, :blocked, :boolean, default: false, null: false
    add_index :voters, :blocked
  end

  def down
    remove_index :voters, :blocked
    rename_column :voters, :blocked, :blocked_number_id
    change_column :voters, :blocked_number_id, :integer, default: nil, null: true
    add_index :voters, :blocked_number_id, name: 'index_on_blocked_number_id'
  end
end
