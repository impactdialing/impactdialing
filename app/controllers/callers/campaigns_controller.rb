module Callers
  class CampaignsController < ::CallerController
    layout 'caller'

    def index
      @campaigns = @caller.campaigns.manual.active.using_web_ui
    end

    def show
      unless @caller.account.activated?
        flash_now(:warning, "Your account is not funded. Please contact your account administrator.")
      end
      @campaign = @caller.campaigns.find(params[:id])
      
      if @campaign.time_period_exceed?
        flash_now(:warning, "In this campaign you can not make calls right now. Because this campaign is active between #{@campaign.start_time.hour > 12 ? @campaign.start_time.hour-12 : @campaign.start_time.hour} "+ (@campaign.start_time.hour <= 12 ? "AM" : "PM")+
        " to #{@campaign.end_time.hour > 12 ? @campaign.end_time.hour-12 : @campaign.end_time.hour} "+ (@campaign.end_time.hour <= 12 ? "AM" : "PM"))
      end
      @selected_voter_fields = @campaign.script.try(:voter_fields) ? eval(@campaign.script.try(:voter_fields)) : []
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
