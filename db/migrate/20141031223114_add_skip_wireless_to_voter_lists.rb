class AddSkipWirelessToVoterLists < ActiveRecord::Migration
  def change
    add_column :voter_lists, :skip_wireless, :boolean, default: true
  end
end
