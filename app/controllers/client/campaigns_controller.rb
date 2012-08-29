module Client
  class CampaignsController < ::CampaignsController
    layout 'client'

    before_filter :new_campaign, :only => [:new, :create]
    before_filter :load_campaign, :only => [:show, :update, :destroy]
    before_filter :load_other_stuff, :only => [:new, :create, :show, :update]

    respond_to :html
    respond_to :json, :only => [:index, :create, :show, :update, :destroy]

    def new
      @campaign.type = "Progressive"
      @campaign.time_zone = "Pacific Time (US & Canada)"
      @campaign.start_time = Time.parse("9am")
      @campaign.end_time = Time.parse("9pm")
    end

    def create
      @error_action = 'new'
      save_campaign
    end

    def show
    end

    def update
      @error_action = 'show'
      save_campaign
    end

    def index
      respond_to do |format|
        format.html {@campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'}
        format.json {@campaigns = account.campaigns.where(:active => true)}
      end
    end

    def destroy
      if @campaign.callers.any?
        flash_message(:notice, "There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.")
      else
        @campaign.update_attribute(:active, false)
        flash_message(:notice, "Campaign deleted")
      end
      redirect_to :back
    end

    def deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.manual.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
      render 'campaigns/deleted'
    end

    private

    def new_campaign
      @campaign = account.campaigns.new
    end

    def load_campaign
      @campaign = Campaign.find(params[:id])
    end

    def load_other_stuff
      @callers = account.callers.active
      @scripts = account.scripts.manual.active
      @lists = @campaign.voter_lists
      @voter_list = @campaign.voter_lists.new
    end

    def save_campaign
      respond_to do |format|
        format.html do
          if @campaign.update_attributes(params[:campaign])
            flash_message(:notice, "Campaign saved")
            redirect_to client_campaigns_path
          else
            render :action => @error_action
          end
        end
        format.json {respond_with @campaign.update_attributes(params[:campaign])}
      end
    end
  end
end
