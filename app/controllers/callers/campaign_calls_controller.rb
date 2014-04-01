module Callers
  class CampaignCallsController < ::CallerController
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    skip_before_filter :verify_authenticity_token, only: [:call_station]

private
    def current_ability
      @current_ability ||= Ability.new(@caller.account)
    end

public
    def show
    end

    def script
      @campaign = @caller.campaign
      respond_with(@campaign.script)
    end

    def token
      @campaign = @caller.campaign

      if cannot?(:access_dialer, @caller)
        render :json => "Calling has been disabled for this account. Please contact your account admin for assistance.", :status => 422
        return
      end

      if cannot? :start_calling, @caller
        render :json => "Your account is not funded. Please contact your account administrator.", :status => 422
        return
      end

      if @campaign.time_period_exceeded?
        start_time = if @campaign.start_time.hour <= 12
                       "#{@campaign.start_time.hour} AM"
                     else
                      "#{@campaign.start_time.hour-12} PM"
                     end
        end_time = if @campaign.end_time.hour <= 12
                     "#{@campaign.end_time.hour} AM"
                   else
                     "#{@campaign.end_time.hour-12} PM"
                   end
        render(
          json: I18n.t(:campaign_time_period_exceed, {
            :start_time => start_time,
            :end_time => end_time
          })
        )
        return
      end

      caller_session_key = generate_session_key
      @caller_identity = @caller.create_caller_identity(caller_session_key)

      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)

      additional_json = {
        campaign_id: @campaign.id,
        account_id: @caller.account_id,
        twilio_token: twilio_capability.generate,
        phone_number: number_to_phone(Settings.callin_phone, :area_code => true),
        caller_session_key: caller_session_key
      }

      render json: @caller_identity.as_json({root: false}).merge(additional_json)
    end

    # draft new api - eventually moving to grape abstraction
    def service_tokens
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)

      render json: {
        tokens: {
          twilio: twilio_capability.generate,
          pusher: Pusher.key
        }
      }
    end

    # draft new api - eventually moving to grape abstraction
    def call_station
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
