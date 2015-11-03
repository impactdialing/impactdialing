module Callers
  class StationController < ::CallerController
    layout :caller, except: :show
    layout false, only: :show
    
    include ActionView::Helpers::NumberHelper
    respond_to :json, :html

    # it is ok to skip csrf verification for :create, :logout
    # since these are innocuous if called by a nefarious 3rd-party
    #skip_before_filter :verify_authenticity_token, only: [:create, :logout, :hangup_lead]
    skip_before_filter :verify_authenticity_token #, only: [:create, :logout, :hangup_lead]

    before_filter :disable_header_cache, only: [:show]

    before_filter :logout_if_floating_caller, except: [:logout, :login]

    if instrument_actions?
      instrument_action :login, :logout, :create, :script, :twilio_token, :disposition,
                        :hangup_lead, :drop_message
    end

private
    def logout_if_floating_caller
      check_login
      unless @caller.present? and @caller.campaign.present?
        logout and return
      end
    end

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
        elsif @caller.campaign_id.blank? or @caller.campaign.archived?
          flash_now(:error, "Your account is not assigned to a campaign. Please
contact your account administrator.")
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
      token_expiry = ENV['TWILIO_CAPABILITY_TOKEN_TTL'].nil? ? 60 : ENV['TWILIO_CAPABILITY_TOKEN_TTL'].to_i
      render json: {
        twilio_token: twilio_capability.generate(token_expiry)
      }
    end

    # draft new api - eventually moving to grape abstraction
    def create
      unless (_abort = abort_json).empty?
        render _abort and return
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
          name: campaign.name
        },
        permissions: {
          can_drop_message_manually: campaign.caller_can_drop_message_manually?
        }
      }
    end

    # replaces:
    # - caller#call_voter
    def dial
      # future
    end

    # replaces
    # - calls#hangup
    def hangup_lead
      EndRunningCallJob.add_to_queue(params[:sid])
      render nothing: true
    end

    # replaces:
    # - calls#drop_message
    def drop_message
      account_sid = @caller.telephony_provider_account_id
      dialed_call = CallFlow::Call::Dialed.new(account_sid, params[:sid])
      dialed_call.drop_message
      render nothing: true
    end

    # replaces:
    # - calls#submit_result
    # - calls#submit_result_and_stop
    def disposition
      account_sid = @caller.telephony_provider_account_id
      campaign    = @caller.campaign
      source = [
        "ac-#{campaign.account_id}",
        "ca-#{campaign.id}",
        "dm-#{campaign.type}",
        "cl-#{@caller.id}"
      ].join('.')
      if params[:sid].present?
        ImpactPlatform::Metrics.count('dialer.disposition.by_sid', 1, source)
        dialed_call = CallFlow::Call::Dialed.new(account_sid, params[:sid])
      else
        ImpactPlatform::Metrics.count('dialer.disposition.by_id', 1, source)
        caller_session = CallerSession.find(params[:caller_session_id])
        dialed_call = caller_session.dialed_call
      end
      dialed_call.dispositioned(params)
      render nothing: true
    end
  end
end

