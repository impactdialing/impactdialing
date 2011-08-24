module Callers
  class CampaignsController < ::CallerController
    layout 'caller'

    def callin
      #raise params.inspect
      campaign = Campaign.find(params[:id])
      @session = @caller.callin(campaign,params[:caller][:phone])
      render :text => :nothing
    end

    def index
      @campaigns = @caller.campaigns.active.using_web_ui
    end

    def show
      @campaign = @caller.campaigns.find(params[:id])
    end

    def caller_ready

    end
  end
end