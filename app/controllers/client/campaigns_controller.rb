module Client
  class CampaignsController < ::CampaignsController
    layout 'client'

    def deleted
      render 'campaigns/deleted'
    end
  end
end
