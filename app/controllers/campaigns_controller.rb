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

  def verify_callerid
    begin
      @campaign = @user.campaigns.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound => e
      render :text => "Permission denied", :status => 550 and return
    end
    @campaign.check_valid_caller!
    @campaign.save
    ret = if @campaign.caller_id.present? and (not @campaign.caller_id_verified)
            "<div class='msg msg-error'> <p><strong>Your Campaign Caller ID is not verified.</strong></p> </div>"
          end
    render :text => ret
  end
end
