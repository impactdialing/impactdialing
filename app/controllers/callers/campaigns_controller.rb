module Callers
  class CampaignsController < ::CallerController
    layout 'caller'
    
    def index
      @campaigns = @caller.campaigns.manual.active.using_web_ui
    end

    def show
      unless @caller.account.paid
        flash_now(:warning, "Your account is not funded. Please contact your account administrator.")
      end      
      @campaign = @caller.campaigns.find(params[:id])
      @selected_voter_fields = @campaign.script.try(:voter_fields) ? eval(@campaign.script.try(:voter_fields)) : []
      twilio_capability = Twilio::Util::Capability.new(TWILIO_ACCOUNT, TWILIO_AUTH)
      twilio_capability.allow_client_outgoing(TWILIO_APP_SID)
      @token = twilio_capability.generate
      @params = {"PhoneNumber"=> Settings.phone}
    end

    def callin
      campaign = Campaign.find(params[:id])
      @session = @caller.callin(campaign, params[:caller][:phone])
      render :text => :nothing
    end

    def caller_ready
      session = CallerSession.find_by_sid(params[:caller_sid])
      session.update_attributes(:available_for_call => true, :on_call => true)
      render :nothing => true
    end
  end
end
