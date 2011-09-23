class CampaignsController < ClientController
  layout 'v2'
  include DeletableController
  before_filter :load_campaign, :except => [:create, :control, :index, :deleted]
  before_filter :setup_campaigns_paths

  def type_name
    'campaign'
  end

  def create
    campaign = @user.account.campaigns.create!(:script => @user.account.scripts.robo.first, :robo => true)
    redirect_to campaign
  end

  def update
    @campaign.attributes = params[:campaign]
    @campaign.script ||= @user.account.scripts.active.first
    @campaign.voter_lists.disable_all
    @campaign.voter_lists.by_ids(params[:voter_list_ids]).enable_all
    if @campaign.save
      flash_message(:notice, "Campaign saved")
      generate_validation_token_for_caller_id(@campaign) if @campaign.caller_id.present? and (not @campaign.caller_id_verified)
    end
    redirect_to campaign_path(@campaign)
  end

  def index
    @campaigns = active_robo_campaigns
  end

  def show
    unless @campaign.robo?
      redirect_to client_campaign_path(@campaign)
      return
    end
    @scripts = @user.account.scripts.robo.active
    @callers  = account.callers.active
    @lists    = @campaign.voter_lists
    @voters = @campaign.all_voters.active.paginate(:page => params[:page])
    if @campaign.caller_id.blank?
      flash_now(:warning, t(:caller_id_blank))
    end
    @voter_list = @campaign.voter_lists.new
  end

  #TODO: extract html message to partial
  def verify_callerid
    @campaign.check_valid_caller!
    @campaign.save
    ret = if @campaign.caller_id.present? and (not @campaign.caller_id_verified)
            "<div class='msg msg-error'> <p><strong>Your Campaign Caller ID is not verified.</strong></p> </div>"
          end
    render :text => ret
  end

  def control
    @campaigns = active_robo_campaigns
  end

  def running_status
    render :partial => "control_list", :locals => { :campaigns => active_robo_campaigns }
  end

  def start
    @campaign.start
    redirect_to control_campaigns_path
  end

  def stop
    @campaign.stop
    redirect_to control_campaigns_path
  end

  private
  def generate_validation_token_for_caller_id(campaign)
    validation_code = campaign.caller_id_object.validation_code
    if validation_code
      flash_message(:notice, "<font color=red>Please enter code #{validation_code} when called.</font>")
    else
      flash_message(:error, "Could not validate your caller id")
    end
  end

  def active_robo_campaigns
    account.campaigns.active.robo.paginate :page => params[:page], :order => 'id desc'
  end

  def load_campaign
    @campaign = account.all_campaigns.find(params[:campaign_id] || params[:id])
  end

  def setup_campaigns_paths
  end
end
