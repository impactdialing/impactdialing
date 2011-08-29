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
      #raise params.inspect
      campaign = Campaign.find(params[:id])
      @session = @caller.callin(campaign,params[:caller][:phone])
      render :text => :nothing
    end

    def caller_ready
      session = CallerSession.find_by_sid(params[:caller_sid])
      session.update_attributes(:available_for_call => true, :on_call => true)
      render :nothing => true
    end
  end
end