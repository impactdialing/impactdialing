module Client
  class CallersController < ClientController
    include DeletableController
    include TimeZoneHelper
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    before_filter :full_access, :except => [:reassign_to_campaign]
    before_filter :load_campaigns, :except => [:index, :destroy, :reassign_to_campaign]

    respond_to :html, :json

    def index
      respond_to do |format|
        format.html { @callers = account.callers.active.paginate(:page => params[:page]) }
        format.json { respond_with account.callers.active }
      end
    end

    def new
      @caller = account.callers.new(:is_phones_only => params[:is_phones_only])
      load_caller_groups
      respond_with @caller
    end

    def show
      load_caller
      respond_to do |format|
        format.html {redirect_to edit_client_caller_path(@caller)}
        format.json {respond_with @caller}
      end
    end

    def edit
      load_caller
      load_caller_groups
      respond_with @caller
    end

    def update
      load_caller
      save_caller
    end

    def create
      @caller = account.callers.new
      save_caller
    end

    def destroy
      load_caller
      @caller.update_attribute(:active, false)
      flash_message(:notice, "Caller deleted")
      respond_with @caller, location: client_callers_path
    end

    def reassign_to_campaign
      caller = Caller.find_by_id(params[:id])
      caller.update_attributes(:campaign_id => params[:campaign_id])
      caller_session = caller.caller_sessions.find_by_id(params[:session_id])
      caller.reassign_to_another_campaign(caller_session)
      render :nothing => true
    end

    def usage
      @caller = Caller.find(params[:id])
      @campaigns = account.campaigns.manual.for_caller(@caller)
      @campaign = @campaigns.find_by_id(params[:campaign_id])
      @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
      @caller_usage = CallerUsage.new(@caller, @campaign, @from_date, @to_date)
    end

    def call_details
      @caller = Caller.find(params[:id])
      @campaigns = account.campaigns.manual.for_caller(@caller)
      @campaign = @campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.last.try(:campaign) || @caller.campaign
      @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
      @answered_call_stats = @caller.answered_call_stats(@from_date, @to_date, @campaign)
      @questions_and_responses = @campaign.try(:questions_and_responses) || {}
    end

    def type_name
      'caller'
    end

    private

    def load_caller
      @caller = account.callers.find_by_id(params[:id])
    end

    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end

    def load_caller_groups
      @caller_groups = account.caller_groups
    end

    def save_caller
      load_campaigns
      load_caller_groups
      flash_message(:notice, "Caller saved") if @caller.update_attributes(params[:caller])
      respond_with @caller, location: client_callers_path
    end
  end
end
