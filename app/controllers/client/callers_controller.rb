module Client
  class CallersController < ClientController
    include TimeZoneHelper
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    skip_before_filter :check_tos_accepted, :only => [:reassign_to_campaign]
    before_filter :load_and_verify_caller, :except => [:index, :new, :create, :reassign_to_campaign, :usage, :call_details, :type_name, :archived]
    before_filter :load_campaigns, :except => [:index, :destroy, :reassign_to_campaign, :usage, :call_details, :type_name, :archived]
    # pundit authorization methods
    after_action :verify_authorized

    respond_to :html, :json

    def index
      authorize :caller, :index?
      @callers = account.callers.includes(:campaign).active.paginate(:page => params[:page])
      respond_with @callers
    end

    def new
      authorize :caller, :new?
      @caller                = account.callers.new
      @caller.is_phones_only = params[:is_phones_only]
      load_caller_groups
      respond_with @caller
    end

    def show
      authorize :caller, :show?
      respond_with @caller do |format|
        format.html {redirect_to edit_client_caller_path(@caller)}
      end
    end

    def edit
      authorize :caller, :edit?
      load_caller_groups
      respond_with @caller
    end

    def update
      authorize :caller, :update?
      save_caller
      respond_with @caller, location: client_callers_path do |format|
        format.json {render :json => {message: 'Caller updated'}, status: :ok} if @caller.errors.empty?
      end
    end

    def create
      authorize :caller, :create?
      @caller = account.callers.new
      save_caller
      respond_with @caller, location: client_callers_path
    end

    def destroy
      authorize :caller, :destroy?
      @caller.active = false
      @caller.save ? flash_message(:notice, "Caller archived") : flash_message(:error, @caller.errors.full_messages.join)
      respond_with @caller, location: client_callers_path do |format|
        format.json {render :json => {message: 'Caller archived'}, :status => :ok} if @caller.errors.empty?
      end
    end

    def reassign_to_campaign
      authorize :caller, :reassign_to_campaign?
      caller = Caller.find_by_id(params[:id])
      caller.update_attributes(:campaign_id => params[:campaign_id])
      render :nothing => true
    end

    def usage
      authorize :caller, :usage?
      # authorize! :view_reports, @account
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @caller = Caller.find(params[:id])
        campaigns = account.campaigns.for_caller(@caller)
        @campaigns_data = Account.connection.execute(campaigns.select([:name, 'campaigns.id']).uniq.to_sql).to_a
        @campaign = campaigns.find_by_id(params[:campaign_id])
        @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
        @caller_usage = CallerUsage.new(@caller, @campaign, @from_date, @to_date)
      end
    end

    def call_details
      # authorize! :view_reports, @account
      authorize :caller, :call_details?
      @caller = Caller.find(params[:id])
      campaigns = account.campaigns.for_caller(@caller)
      @campaigns_data = Account.connection.execute(campaigns.select([:name, 'campaigns.id']).uniq.to_sql).to_a
      @campaign = campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.last.try(:campaign) || @caller.campaign
      @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
      @answered_call_stats = @caller.answered_call_stats(@from_date, @to_date, @campaign)
      @questions_and_responses = @campaign.try(:questions_and_responses) || {}
    end

    def archived
      authorize :caller, :archived?
      @callers = Caller.archived.for_account(account).paginate(:page => params[:page], :order => 'id desc')
      respond_with @callers do |format|
        format.html{ render 'client/callers/archived' }
        format.json{ render :json => @callers.to_json }
      end
    end

    def restore
      authorize @caller, :restore?
      @caller.active = true
      if @caller.save
        flash_message(:notice, 'Caller restored')
      else
        flash_message(:error, @caller.errors.full_messages.join('; '))
      end
      respond_with @caller, location: client_callers_path do |format|
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

    #This method may need to be deleted
    def type_name
      logger.error("CallersController#type_name was called")
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
      flash_message(:notice, "Caller saved") if @caller.update_attributes(caller_params)
    end

    def caller_params
      params.require(:caller).permit(:name, :username, :campaign_id, :is_phones_only, :caller_group_id, :password)
    end
  end
end
