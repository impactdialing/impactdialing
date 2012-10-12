class AddCampaignTypeToCall < ActiveRecord::Migration
    def change
       add_column :calls, :campaign_type, :string
    end
end
