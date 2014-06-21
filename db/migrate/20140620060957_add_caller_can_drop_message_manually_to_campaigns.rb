class AddCallerCanDropMessageManuallyToCampaigns < ActiveRecord::Migration
  def change
    add_column :campaigns, :caller_can_drop_message_manually, :boolean, default: false
  end
end
