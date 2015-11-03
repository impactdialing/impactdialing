module Client
  class CallerGroupsController < ClientController
    before_filter :load_and_verify_caller_group, :except => [:index, :new, :create]

    respond_to :html, :json

    if instrument_actions?
      instrument_action :index, :create, :show, :update, :destroy
    end

    def index
      @caller_groups = account.caller_groups.paginate(:page => params[:page])
      respond_with @caller_groups
    end

    def new
      @caller_group = account.caller_groups.new
      @campaigns = account.campaigns.active
      respond_with @caller_group
    end

    def create
      @caller_group = account.caller_groups.new(caller_group_params)
      if @caller_group.save
        flash_message(:notice, I18n.t('activerecord.successes.models.caller_group.saved'))
      else
        @campaigns = account.campaigns.active
      end
      respond_with @caller_group, location: client_caller_groups_path
    end

    def show
      respond_with @caller_group do |format|
        format.html {redirect_to edit_client_caller_group_path(@caller_group)}
      end
    end

    def edit
      @campaigns = account.campaigns.active
      respond_with @caller_group
    end

    def update
      save_result = @caller_group.update_attributes(caller_group_params)
      unless save_result
        @campaigns = account.campaigns.active
      else
        if @caller_group.previous_changes.keys.include?('campaign_id')
          flash_message(:notice, I18n.t('activerecord.successes.models.caller_group.reassigned'))
        else
          flash_message(:notice, I18n.t('activerecord.successes.models.caller_group.saved'))
        end
      end
      respond_with @caller_group, location: client_caller_groups_path do |format|
       format.json {render :json => {message: 'Caller Group updated'}, :status => :ok} if @caller_group.errors.empty?
      end
    end

    def destroy
      @caller_group.destroy
      flash_message(:notice, I18n.t('activerecord.successes.models.caller_group.deleted'))
      respond_with @caller_group, location: client_caller_groups_path do |format|
        format.json {render json: {message: 'Caller Group deleted'}, status: :ok} if @caller_group.errors.empty?
      end
    end

  private
    def load_and_verify_caller_group
      begin
        @caller_group = CallerGroup.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @caller_group.account != account
        render :json => {message: 'Cannot access caller group'}, :status => :unauthorized
        return
      end
    end

    def caller_group_params
      params.require(:caller_group).permit(:name, :campaign_id)
    end
  end
end
