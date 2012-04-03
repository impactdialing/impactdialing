module Callers
  class CampaignsController < ::CallerController
    layout 'caller_campaign'
    
    def show      
      unless @caller.account.activated?
        flash_now(:warning, "Your account is not funded. Please contact your account administrator.")
      end
      @campaign = @caller.campaign
      @caller_session = CallerSession.find(params[:caller_session])
      if @campaign.time_period_exceed?
        flash_now(:warning, I18n.t(:campaign_time_period_exceed, :start_time => @campaign.start_time.hour <= 12 ? "#{@campaign.start_time.hour} AM" : "#{@campaign.start_time.hour-12} PM",
         :end_time => @campaign.end_time.hour <= 12 ? "#{@campaign.end_time.hour} AM" : "#{@campaign.end_time.hour-12} PM")) 
      end
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)
      @token = twilio_capability.generate
      @phone_number = Settings.phone
    end

    def callin
      campaign = Campaign.find(params[:id])
      @session = @caller.callin(campaign, params[:caller][:phone])
      render :text => :nothing
    end

    def caller_ready
      caller_session = CallerSession.find_by_sid(params[:caller_sid])
      caller_session.update_attributes(:available_for_call => true, :on_call => true)
      render :nothing => true
    end
  end
end
