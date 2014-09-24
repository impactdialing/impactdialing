module Callers
  class StationController < ::CallerController
    layout false, only: :show
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    skip_before_filter :verify_authenticity_token, only: [:create]

    before_filter :disable_header_cache, only: [:show]

private
    def disable_header_cache
      expires_now
    end

    def check_login
      if session[:caller].blank?
        redirect_to callveyor_login_path
        return
      end
      begin
        @caller = Caller.find(session[:caller])
      rescue
        logout
      end
    end

    def auto_reassign_caller_campaign!
      return if @caller.campaign_id == params[:campaign_id].try(:to_i)
      
      begin
        campaign = @caller.account.campaigns.find params[:campaign_id]
      rescue ActiveRecord::RecordNotFound => e
        logger.error("Exception ActiveRecord::RecordNotFound when auto-reassign caller campaign attempted. Caller[#{@caller.id}] CurrentCampaign[#{@caller.campaign.id}] RequestedCampaign[#{params[:campaign_id]}]")
        return
      end

      prev_campaign_id = @caller.campaign_id
      @caller.update_attributes!(campaign_id: campaign.id)
      logger.info("Auto-reassigned Caller[#{@caller.id}] PrevCampaign[#{prev_campaign_id}] NewCampaign[#{@caller.campaign_id}]")
    end

public
    # draft new html/client entry point
    def show
      auto_reassign_caller_campaign! if params[:campaign_id].present?
    end

    def logout
      session[:caller] = nil
      redirect_to callveyor_login_path
    end

    def login
      if !params[:username].blank?
        @caller = Caller.find_by_username_and_password(params[:username], params[:password])
        if @caller.blank?
          flash_now(:error, "Wrong username or password.")
        elsif !@caller.active?
          flash_now(:error, "That account has been deleted.")
        else
          # pass campaign_id along to #show to enable auto-reassignment
          pass_along_params = {}
          if params[:campaign_id]
            pass_along_params[:campaign_id] = params[:campaign_id]
          end
          # /pass campaign_id along to #show to enable auto-reassignment
          session[:caller] = @caller.id
          redirect_to callveyor_path(pass_along_params)
        end
      end
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
        twilio_token: twilio_capability.generate(5)
      }
    end

    # draft new api - eventually moving to grape abstraction
    def create
      abort = abort_json
      unless abort.empty?
        render abort and return
      end

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
          type: campaign.type,
        },
        permissions: {
          can_drop_message_manually: campaign.caller_can_drop_message_manually?
        }
      }
    end
  end
end
