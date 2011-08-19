module Callers
  class CampaignsController < ::CallerController
    layout 'caller'

    def index
      @campaigns = @caller.campaigns.active.using_web_ui
    end

    def show
      @campaign = @caller.campaigns.find(params[:id])
    end
  end
end