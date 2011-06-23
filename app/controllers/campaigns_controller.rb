class CampaignsController < ClientController
  layout 'v2'

  def deleted
    @campaigns = @user.campaigns.deleted.paginate(:page => params[:page], :order => "id desc")
  end

  def restore
    Campaign.find(params[:campaign_id]).tap do |c|
      c.restore
      c.save
    end
    redirect_to :back
  end

  def create
    campaign = @user.campaigns.create!(:script => @user.scripts.first, :predective_type => 'algorithm1', :callers => @user.callers.active)
    redirect_to campaign_path(campaign)
  end


  def index
    @campaigns = @user.campaigns.active.paginate :page => params[:page], :order => 'id desc'
  end

  def show
    @campaign = Campaign.find(params[:id])
    @callers  = @user.callers.active
    @lists    = @campaign.voter_lists

    @voters = @campaign.all_voters.active.paginate(:page => params[:page])
    if @campaign.caller_id.blank?
      flash_now(:warning, t(:caller_id_blank))
    end
    @voter_list = @campaign.voter_lists.new
  end
end
