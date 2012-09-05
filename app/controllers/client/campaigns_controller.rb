module Client
  class CampaignsController < ::CampaignsController
    layout 'client'
    respond_to :html, :json

    def index
      @campaigns = account.campaigns.active.manual.paginate :page => params[:page]
      respond_with @campaigns
    end

    def new
      @campaign = account.campaigns.new(type: Campaign::Type::PROGRESSIVE,
                                        time_zone: "Pacific Time (US & Canada)",
                                        start_time: Time.parse("9am"),
                                        end_time: Time.parse("9pm"))
      load_scripts
      new_list
      respond_with @campaign
    end

    def create
      @campaign = account.campaigns.new
      save_campaign
    end

    def show
      load_campaign
      puts @campaign.inspect
      respond_with @campaign do |format|
        format.html {redirect_to edit_client_campaign_path(@campaign)}
      end
    end

    def edit
      load_campaign
      load_scripts
      new_list
      respond_with @campaign
    end

    def update
      load_campaign
      save_campaign
    end

    def destroy
      load_campaign
      puts @campaign.inspect
      @campaign.active = false
      @campaign.save ? flash_message(:notice, "Campaign deleted") : flash_message(:error, @campaign.errors.full_messages.join)
      respond_with(@campaign, location: client_campaigns_url)
    end

    def deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.manual.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
      render 'campaigns/deleted'
    end

    private

    def load_campaign
      @campaign = account.campaigns.find(params[:id])
    end

    def load_scripts
      @scripts = account.scripts.manual.active
    end

    def new_list
      @voter_list = @campaign.voter_lists.new
    end

    def save_campaign
      load_scripts
      # new_list
      flash_message(:notice, "Campaign saved") if @campaign.update_attributes(params[:campaign])
      respond_with @campaign, location: client_campaigns_path
    end
  end
end
