class ChangeVotersEnabledToInteger < ActiveRecord::Migration
  def up
    change_column :voters, :enabled, :integer, default: 0, null: false
  end

  def down
    change_column :voters, :enabled, :boolean, default: false, null: false
  end
end
