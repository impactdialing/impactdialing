module Broadcast
  class CampaignsController < ::CampaignsController
    layout 'client'

    def deleted
      render 'campaigns/deleted'
    end

    def setup_campaigns_paths
      @deleted_campaigns_path = broadcast_deleted_campaigns_path
      @campaigns_path = broadcast_campaigns_path
    end
  end
end
