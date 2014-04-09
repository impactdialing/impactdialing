module Callers
  class StationController < ::CallerController
    layout false
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    skip_before_filter :verify_authenticity_token, only: [:create]

private
    def current_ability
      @current_ability ||= Ability.new(@caller.account)
    end

public
    # draft new html/client entry point
    def show
    end

    def script
      @campaign = @caller.campaign
      respond_with(@campaign.script)
    end

    # draft new api - eventually moving to grape abstraction
    def twilio_token
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)

      render json: {
        twilio_token: twilio_capability.generate
      }
    end

    # draft new api - eventually moving to grape abstraction
    def create
      campaign = @caller.campaign
      caller_session_key = generate_session_key
      caller_identity = @caller.create_caller_identity(caller_session_key)

      render json: {
        call_station: {
          phone_number: number_to_phone(Settings.callin_phone, area_code: true)
        },
        caller: {
          id: @caller.id,
          account_id: @caller.account_id,
          session_key: caller_identity.session_key,
          pin: caller_identity.pin
        },
        campaign: {
          id: campaign.id,
          type: campaign.type
        }
      }
    end
  end
end
