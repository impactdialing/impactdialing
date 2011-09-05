module Broadcast
  class CampaignsController < ::CampaignsController
    layout 'client'

    def deleted
      render 'campaigns/deleted'
    end

    def deleted_campaigns_path
      broadcast_deleted_campaigns_path
    end
  end
end
