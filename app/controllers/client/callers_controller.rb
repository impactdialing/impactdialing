module Client
  class CallersController < ClientController
    include TimeZoneHelper
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    before_filter :full_access, :except => [:reassign_to_campaign, :usage, :call_details]
    before_filter :load_and_verify_caller, :except => [:index, :new, :create, :reassign_to_campaign, :usage, :call_details, :type_name, :deleted]
    before_filter :load_campaigns, :except => [:index, :destroy, :reassign_to_campaign, :usage, :call_details, :type_name, :deleted]

    respond_to :html, :json

    def index
      @callers = account.callers.active.paginate(:page => params[:page])
      respond_with @callers
    end

    def new
      @caller = account.callers.new(:is_phones_only => params[:is_phones_only])
      load_caller_groups
      respond_with @caller
    end

    def show
      respond_with @caller do |format|
        format.html {redirect_to edit_client_caller_path(@caller)}
      end
    end

    def edit
      load_caller_groups
      respond_with @caller
    end

    def update
      save_caller
      respond_with @caller, location: client_callers_path do |format|
        format.json {render :json => {message: 'Caller updated'}, status: :ok} if @caller.errors.empty?
      end
    end

    def create
      @caller = account.callers.new
      save_caller
      respond_with @caller, location: client_callers_path
    end

    def destroy
      @caller.active = false
      @caller.save ? flash_message(:notice, "Caller deleted") : flash_message(:error, @caller.errors.full_messages.join)
      respond_with @caller, location: client_callers_path do |format|
        format.json {render :json => {message: 'Caller deleted'}, :status => :ok} if @caller.errors.empty?
      end
    end

    def reassign_to_campaign
      caller = Caller.find_by_id(params[:id])
      caller.update_attributes(:campaign_id => params[:campaign_id])
      caller_session = caller.caller_sessions.find_by_id(params[:session_id])
      caller.reassign_to_another_campaign(caller_session)
      render :nothing => true
    end

    def usage
      Octopus.using(:read_slave1) do
        @caller = Caller.find(params[:id])
        campaigns = account.campaigns.for_caller(@caller)
        @campaigns_data = Account.connection.execute(campaigns.select([:name, 'campaigns.id']).uniq.to_sql).to_a
        @campaign = campaigns.find_by_id(params[:campaign_id])
        @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
        @caller_usage = CallerUsage.new(@caller, @campaign, @from_date, @to_date)
      end
    end

    def call_details
      @caller = Caller.find(params[:id])
      campaigns = account.campaigns.for_caller(@caller)
      @campaigns_data = Account.connection.execute(campaigns.select([:name, 'campaigns.id']).uniq.to_sql).to_a
      @campaign = campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.last.try(:campaign) || @caller.campaign
      @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
      @answered_call_stats = @caller.answered_call_stats(@from_date, @to_date, @campaign)
      @questions_and_responses = @campaign.try(:questions_and_responses) || {}
    end

    def deleted
      @callers = Caller.deleted.for_account(account).paginate(:page => params[:page], :order => 'id desc')
      respond_with @callers do |format|
        format.html{render 'client/callers/deleted'}
        format.json {render :json => @callers.to_json}
      end
    end

    def restore
      @caller.active = true
      save_caller
      respond_with @caller,  location: client_callers_path do |format|
        format.json { render :json => {message: "Caller restored" }, :status => :ok } if @caller.errors.empty?
        format.html do
          if @caller.errors.any?
            @caller.active = true
            render 'edit'
          else
            redirect_to client_callers_path
          end
        end
      end
    end

    def type_name
      'caller'
    end

    private

    def load_and_verify_caller
      begin
        @caller = Caller.find(params[:id] || params[:caller_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @caller.account != account
        render :json => {message: 'Cannot access caller'}, :status => :unauthorized
        return
      end
    end

    def load_campaigns
      @campaigns = account.campaigns.active
    end

    def load_caller_groups
      @caller_groups = account.caller_groups
    end

    def save_caller
      load_campaigns
      load_caller_groups
      flash_message(:notice, "Caller saved") if @caller.update_attributes(params[:caller])
    end
  end
end
