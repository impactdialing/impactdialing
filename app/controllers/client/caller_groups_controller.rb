module Client
  class CallerGroupsController < ClientController
    respond_to :html, :json

    def index
      respond_to do |format|
        format.html {@caller_groups = account.caller_groups.paginate(:page => params[:page])}
        format.json {respond_with account.caller_groups}
      end
    end

    def new
      new_caller_group
      load_campaigns
      respond_with @caller_group
    end

    def create
      new_caller_group
      save_caller_group
    end

    def show
      load_caller_group
      respond_to do |format|
        format.html {redirect_to edit_client_caller_group_path(@caller_group)}
        format.json {respond_with @caller_group}
      end
    end

    def edit
      load_caller_group
      load_campaigns
      respond_with @caller_group
    end

    def update
      load_caller_group
      save_caller_group
    end

    def destroy
      load_caller_group
      @caller_group.destroy
      flash_message(:notice, "Caller Group deleted")
      respond_with @caller_group, location: client_caller_groups_path
    end

    private

    def new_caller_group
      @caller_group = account.caller_groups.new
    end

    def load_caller_group
      @caller_group = CallerGroup.find(params[:id])
    end

    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end

    def save_caller_group
      load_campaigns
      flash_message(:notice, "Caller Group saved") if @caller_group.update_attributes(params[:caller_group])
      respond_with @caller_group, location: client_caller_groups_path
    end
  end
end
