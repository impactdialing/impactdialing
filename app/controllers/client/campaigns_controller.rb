module Client
  class CampaignsController < ::CampaignsController
    layout 'client'
    respond_to :html, :json

    def index
      respond_to do |format|
        format.html {@campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'}
        format.json {@campaigns = account.campaigns.where(:active => true)}
      end
    end

    def new
      @campaign = account.campaigns.new(type: Campaign::Type::PROGRESSIVE, time_zone: "Pacific Time (US & Canada)", start_time: Time.parse("9am"),
      end_time: Time.parse("9pm"), account_id: account.id)
      load_scripts
      new_list
      respond_with @campaign
    end

    def create
      @campaign = account.campaigns.new
      load_scripts
      new_list
      save_campaign
    end

    def show
      @campaign = account.campaigns.find_by_id(params[:id])
      respond_to do |format|
        format.html {redirect_to edit_client_campaign_path(@campaign)}
        format.json {respond_with @campaign}
      end
    end

    def edit
      @campaign = account.campaigns.find_by_id(params[:id])
      load_scripts
      new_list
    end

    def update
      @campaign = account.campaigns.find_by_id(params[:id])
      load_scripts
      new_list
      save_campaign
    end

    def destroy
      @campaign = account.campaigns.find_by_id(params[:id])
      @campaign.active = false
      @campaign.save ? flash_message(:notice, "Campaign deleted") : flash_message(:error, @campaign.errors.full_messages.join)
      respond_with(@campaign, location:  client_campaigns_url)
    end

    def deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.manual.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
      render 'campaigns/deleted'
    end

    private

    def load_scripts
      @scripts = account.scripts.manual.active
    end

    def new_list
      @voter_list = @campaign.voter_lists.new
    end

    def save_campaign
      flash_message(:notice, "Campaign saved") if @campaign.update_attributes(params[:campaign])
      respond_with(@campaign, location: client_campaigns_url)
    end
  end
end
