module Client
  class CallersController < ClientController
    include DeletableController
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    before_filter :full_access, :except => [:reassign_to_campaign]
    before_filter :load_caller, :only => [:show, :update, :destroy]
    before_filter :load_campaigns, :except => [:index, :destroy, :reassign_to_campaign]

    def index
      @callers = Caller.where(:active => true, :account_id => account.id).order(:name).paginate(:page => params[:page])
    end

    def new
      @caller = account.callers.new(:is_phones_only => params[:is_phones_only])
    end

    def show
    end

    def update
      if @caller.is_on_call? && (params[:caller][:campaign_id] != @caller.campaign.id)
        flash_message(:error, "This caller is logged in and so can't be changed to a new campaign from this screen. To reassign them to a new campaign, please use the Monitor tab.")
        render :action => "new"
      else
        if @caller.update_attributes(params[:caller])
          flash_message(:notice, "Caller saved")
          redirect_to :action => "index"
        else
          render :action => "new"
        end
      end
    end

    def create
      @caller = account.callers.new(params[:caller])
      if @caller.save
        flash_message(:notice, "Caller saved")
        redirect_to :action => "index"
      else
        render :action => "new"
      end
    end

    def destroy
      @caller.update_attribute(:active, false)
      flash_message(:notice, "Caller deleted")
      redirect_to :action=>"index"
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

    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end

    def load_caller
      @caller = account.callers.find_by_id(params[:id])
    end
  end
end
