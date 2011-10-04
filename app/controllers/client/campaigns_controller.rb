module Client
  class CampaignsController < ::CampaignsController
    layout 'client'

    def show
      if @campaign.robo
        redirect_to broadcast_campaign_path(@campaign)
        return
      end
      check_warning
      @breadcrumb=[{"Campaigns" => client_campaigns_path}, @campaign.name]

      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @voters = @campaign.all_voters.active.paginate(:page => params[:page])
      @scripts = @user.account.scripts.manual.active

      unless @campaign.caller_id
        flash_now(:warning, "When you make calls with this campaign, you need a phone number to use for the Caller ID. Enter the phone number you want to use for your Caller ID and click Verify. To prevent abuse, the system will call that number and ask you to enter a validation code that will appear on your screen. Until you do this, you can't make calls with this campaign.")
      end
      @show_voter_buttons = @user.show_voter_buttons
      @voter_list = @campaign.voter_lists.new
    end

    def index
      @breadcrumb="Campaigns"
      @campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'
      render 'campaigns/index'
    end

    def destroy
      if !@campaign.blank?
        @campaign.update_attribute(:active, false)
      end
      flash_message(:notice, "Campaign deleted")
      redirect_to :back
    end

    def deleted
      render 'campaigns/deleted'
    end

    def setup_campaigns_paths
      @deleted_campaigns_path = client_deleted_campaigns_path
      @campaigns_path = client_campaigns_path
    end

    def create
      campaign = account.campaigns.create(:predective_type => 'algorithm1', :script => @user.account.scripts.first, :callers => account.callers.active)
      redirect_to client_campaign_path(campaign)
    end

    def clear_calls
      if current_user.admin?
        campaign = Campaign.find(params[:campaign_id])
        campaign.clear_calls
        flash_message(:notice, "Calls cleared")
        redirect_to :back
      else
        render :text => 'unauthorized', :status => :unauthorized
      end
    end
  end
end
