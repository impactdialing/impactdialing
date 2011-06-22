class CampaignsController < ClientController
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
    @campaigns = Campaign.active.for_user(@user).paginate :page => params[:page], :order => 'id desc'
  end

  def show
    @campaign = Campaign.find(params[:id])
    @callers = @user.callers.active
    @lists = @campaign.voter_lists

    @voters = @campaign.all_voters.active.paginate(:page => params[:page])
    flash_now(:warning, "When Impact Dialing makes a call, it needs a phone number to use for the Caller ID. Enter the phone number you want to use for your Caller ID and click Verify. To prevent abuse, Impact Dialing will call that number and ask you to enter a validation code that will appear on your screen. Until you do this, you can't make calls with this campaign.") if @campaign.caller_id.blank?
    @voter_list = @campaign.voter_lists.new
  end
end
