module Client
  class CallerGroupsController < ClientController
    respond_to :html
    respond_to :json, except: [:new, :edit]

    def index
      respond_to do |format|
        format.html {@caller_groups = account.caller_groups.paginate(:page => params[:page])}
        format.json {respond_with account.caller_groups}
      end
    end

    def new
      @caller_group = account.caller_groups.new
      load_campaigns
    end

    def create
      @caller_group = account.caller_groups.new
      @error_action = 'new'
      save_caller_group
    end

    def show
      load_caller_group
      load_campaigns
      respond_with @caller_group
    end

    def update
      @error_action = 'show'
      load_caller_group
      save_caller_group
    end

    def destroy
      load_caller_group
      respond_to do |format|
        format.html do
          @caller_group.destroy
          flash_message(:notice, "Caller Group deleted")
          redirect_to client_caller_groups_path
        end
        format.json {respond_with @caller_group.destroy}
      end
    end

    private

    def load_caller_group
      @caller_group = CallerGroup.find(params[:id])
    end

    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end

    def save_caller_group
      respond_to do |format|
        format.html do
          if @caller_group.update_attributes(params[:caller_group])
            flash_message(:notice, "Caller Group saved")
            redirect_to :action => "index"
          else
            load_campaigns
            render :action => @error_action
          end
        end
        format.json {respond_with @caller_group.update_attributes(params[:caller])}
      end
    end
  end
end
