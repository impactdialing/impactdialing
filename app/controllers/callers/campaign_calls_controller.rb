module Callers
  class CampaignCallsController < ::CallerController
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    def show

    end

    def script
      @campaign = @caller.campaign
      respond_with(@campaign.script)
    end

    def token
      @campaign = @caller.campaign
      unless @caller.account.activated?
        render :json => "Your account is not funded. Please contact your account administrator.", :status => 422
        return
      end
      if @campaign.time_period_exceeded?
        render json: I18n.t(:campaign_time_period_exceed, :start_time => @campaign.start_time.hour <= 12 ? "#{@campaign.start_time.hour} AM" : "#{@campaign.start_time.hour-12} PM",
         :end_time => @campaign.end_time.hour <= 12 ? "#{@campaign.end_time.hour} AM" : "#{@campaign.end_time.hour-12} PM")
        return
      end
      @caller_identity = @caller.create_caller_identity(generate_session_key)
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)
      render json: @caller_identity.as_json.merge({twilio_token: twilio_capability.generate,
       phone_number: number_to_phone(Settings.callin_phone, :area_code => true)})
    end

  end
end