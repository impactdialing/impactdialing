class CampaignsController < ClientController
  layout 'v2'
  include DeletableController

  def type_name
    'campaign'
  end

  def create
    campaign = @user.campaigns.create!(:script => @user.scripts.first, :predective_type => 'algorithm1', :callers => @user.callers.active)
    redirect_to campaign_path(campaign)
  end

  def index
    @campaigns = Campaign.active.for_user(@user).paginate :page => params[:page], :order => 'id desc'
  end

  def show
    @campaign = Campaign.find(params[:id])
    @callers = @user.callers.active
    @lists = @campaign.voter_lists

    @voters = @campaign.all_voters.active.paginate(:page => params[:page])
    flash_now(:warning, t(:caller_id_blank)) if @campaign.caller_id.blank?
    @voter_list = @campaign.voter_lists.new
  end
end
