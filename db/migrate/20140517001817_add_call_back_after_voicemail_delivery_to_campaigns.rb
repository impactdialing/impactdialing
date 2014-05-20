class AddCallBackAfterVoicemailDeliveryToCampaigns < ActiveRecord::Migration
  def change
    add_column :campaigns, :call_back_after_voicemail_delivery, :boolean, default: false
  end
end
