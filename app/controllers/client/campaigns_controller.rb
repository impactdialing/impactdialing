module Client
  class CampaignsController < ::CampaignsController
    layout 'client'
    respond_to :html
    respond_to :json, :only => [:index, :create, :show, :update, :destroy]

    def new
      @campaign = account.campaigns.new(type: Campaign::Type::PROGRESSIVE, time_zone: "Pacific Time (US & Canada)", start_time: Time.parse("9am"), 
      end_time: Time.parse("9pm"), account_id: account.id)
      @scripts = account.scripts.manual.active
      @voter_list = @campaign.voter_lists.new
    end

    def create
      @error_action = 'new'
      account = Account.find(params[:campaign][:account_id])
      @campaign = account.campaigns.new
      save_campaign
    end

    def show
      @campaign = Campaign.find(params[:id])
      @scripts = account.scripts.manual.active
      @voter_list = @campaign.voter_lists.new
    end

    def update
      @error_action = 'show'
      @campaign = Campaign.find(params[:id])
      save_campaign
    end

    def index
      respond_to do |format|
        format.html {@campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'}
        format.json {@campaigns = account.campaigns.where(:active => true)}
      end
    end

    def destroy
      @campaign = Campaign.find(params[:id])
      @campaign.active = false
      @campaign.save ? flash_message(:notice, "Campaign deleted") : flash_message(:error, @campaign.errors.full_messages.join)
      redirect_to :back
    end

    def deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.manual.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
      render 'campaigns/deleted'
    end

    private

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
