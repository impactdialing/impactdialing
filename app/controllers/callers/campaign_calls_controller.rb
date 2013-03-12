module Callers
  class CampaignCallsController < ::CallerController
    respond_to :json

    def show
      @campaign = @caller.campaign
      unless @caller.account.activated?
        @campaign.errors.add(:base, "Your account is not funded. Please contact your account administrator.")
      end
      if @campaign.time_period_exceeded?
        @campaign.errors.add(:base, I18n.t(:campaign_time_period_exceed, :start_time => @campaign.start_time.hour <= 12 ? "#{@campaign.start_time.hour} AM" : "#{@campaign.start_time.hour-12} PM",
         :end_time => @campaign.end_time.hour <= 12 ? "#{@campaign.end_time.hour} AM" : "#{@campaign.end_time.hour-12} PM"))
      end
      respond_with(@campaign.script)
    end

    def token
      @caller_identity = @caller.create_caller_identity(generate_session_key)
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)
      respond_with(@caller_identity.as_json.merge({twilio_token: twilio_capability.generate, phone_number: Settings.callin_phone})
    end

  end
end