module Client
  class CampaignsController < ::CampaignsController
    layout 'client'
    
     def new
      @campaign = Campaign.new
     end

    def show
      if @campaign.robo
        redirect_to broadcast_campaign_path(@campaign)
        return
      end
      check_warning
      @breadcrumb=[{"Campaigns" => client_campaigns_path}, @campaign.name]

      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @voters = @campaign.all_voters.active.default_order.paginate(:page => params[:page])
      @scripts = account.scripts.manual.active

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
    
    def update
      @campaign = account.campaigns.find_by_id(params[:id])
      if @campaign.update_attributes(params[:campaign])      
        flash_message(:notice, "Campaign updated")
        redirect_to :action=>"index"          
      else
        render :action=>"new"    
      end      
    end

    def create
      @campaign =  Campaign.new(params[:campaign])
      code=""
      if @campaign.valid?        
        code = @campaign.verify_caller_id if (!@campaign.caller_id_verified || !@campaign.caller_id.blank?)      
        @campaign.update_campaign_with_account_information(account)
        @campaign.save
        if params[:listsSent]
          @campaign.disable_voter_list          
          params[:voter_list_ids].each{ |id| enable_voter_list(id) } unless params[:voter_list_ids].blank?
        end
        account.callers.active.each { |caller| @campaign.callers << caller }        
        if code.blank?
          flash_message(:notice, "Campaign saved")
        else
          flash_message(:notice, "Campaign saved.  <font color=red>Enter code #{code} when called.</font>")
        end
        redirect_to client_campaign_path(@campaign)
      else
        render :action=>"new"  
      end      
    end

    def clear_calls
      if current_user.admin?
        campaign = Campaign.find(params[:campaign_id])
        campaign.clear_calls
        flash_message(:notice, "Calls cleared")
        redirect_to client_campaign_path(campaign)
      else
        render :text => 'unauthorized', :status => :unauthorized
      end
    end
  end
end
