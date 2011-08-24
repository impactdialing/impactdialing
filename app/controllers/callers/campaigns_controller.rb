module Callers
  class CampaignsController < ::CallerController
    layout 'caller'

    def index
      @campaigns = @caller.campaigns.active.using_web_ui
    end

    def show
      @campaign = @caller.campaigns.find(params[:id])
    end

    def callin
      campaign = Campaign.find(params[:id])
      @session = @caller.callin(campaign,params[:callin_from])
      render :nothing => true
    end
  end
end