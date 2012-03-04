module Broadcast
  class CampaignsController < ::CampaignsController
    layout 'client'

    def deleted
      render 'campaigns/deleted'
    end
    
    def load_deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.robo.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
    end    

    def setup_campaigns_paths
      @deleted_campaigns_path = broadcast_deleted_campaigns_path
      @campaigns_path = broadcast_campaigns_path
    end
  end
end
