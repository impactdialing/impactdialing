class AddCampaignTypeToCall < ActiveRecord::Migration
  def change
    def change
       add_column :calls, :campaign_type, :string
    end
    
  end
end
