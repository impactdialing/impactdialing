module Client
  class CampaignsController < ::CampaignsController
    layout 'client'

    def new
      @campaign = Progressive.new(:account_id => account.id)
      @campaign.save(:validate => false)
      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @scripts = account.scripts.manual.active
      @voter_list = @campaign.voter_lists.new
    end

    def show
      check_warning
      @breadcrumb=[{"Campaigns" => client_campaigns_path}, @campaign.name]

      @callers = account.callers.active
      @lists = @campaign.voter_lists
      @scripts = account.scripts.manual.active
      @voter_list = @campaign.voter_lists.new
      if (@campaign.robo)
        redirect_to broadcast_campaign_path(@campaign)
      end
    end

    def index
      @breadcrumb="Campaigns"
      @campaigns = account.campaigns.active.manual.paginate :page => params[:page], :order => 'id desc'
    end

    def destroy
      unless @campaign.callers.empty? 
        flash_message(:notice, "There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.")
        redirect_to :back
        return
      end
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
      @campaign = Campaign.find_by_id(params[:id])
      @campaign.account = account
      @campaign.update_attributes(params[:campaign])
      @campaign.type = params[:campaign][:type]
      begin
        @campaign.save!      
      rescue ActiveRecord::RecordInvalid => e
        puts e.backtrace
        puts "\n"
        puts e
        flash_message(:error, "You cannot change dialing modes while callers are logged in.")
        redirect_to :back
        return
      end
      @scripts = @campaign.account.scripts
      @lists = @campaign.voter_lists
      @voter_list = @campaign.voter_lists.new
      if @campaign.valid?
        @campaign.script ||= @campaign.account.scripts.first
        @campaign.disable_voter_list
        params[:voter_list_ids].each { |id| VoterList.enable_voter_list(id) } unless params[:voter_list_ids].blank?
        flash_message(:notice, "Campaign saved")
        redirect_to client_campaigns_path
      else
        @callers = account.callers.active
        respond_to do |format|
          format.js 
          format.html{render :action =>"show"}
        end
      end
    end

    def create
      @campaign = new_type_campaign(params)
      @campaign.account = account
      @campaign.script ||= @campaign.account.scripts.first
      if @campaign.save
        if params[:listsSent]
          @campaign.disable_voter_list
          params[:voter_list_ids].each { |id| enable_voter_list(id) } unless params[:voter_list_ids].blank?
        end
        flash_message(:notice, "Campaign saved")
        redirect_to client_campaigns_path
      else
        render :action=>"new"
      end
    end
    
    def load_deleted
      self.instance_variable_set("@#{type_name.pluralize}", Campaign.deleted.manual.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc'))
    end
    
    private
    
    def new_type_campaign(params)
      if params[:campaign][:type] == "Preview"
        Preview.new(params[:campaign])
      elsif params[:campaign][:type] == "Progressive"
        Progressive.new(params[:campaign])
      elsif params[:campaign][:type] == "Predictive"
        Predictive.new(params[:campaign])
      end
    end
    

  end
end
