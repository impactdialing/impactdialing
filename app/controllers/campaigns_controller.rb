class CampaignsController < ClientController
  layout 'v2'
  include DeletableController

  def type_name
    'campaign'
  end

  def create
    campaign = @user.campaigns.new
    campaign.script = @user.scripts.first
    campaign.predective_type = 'algorithm1'
    campaign.callers << @user.callers.active
    campaign.save!
    redirect_to campaign_path(campaign)
  end

  def update
    begin
      campaign = @user.all_campaigns.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound => e
      render :text => "Permission denied", :status => 550 and return
    end

    campaign.attributes = params[:campaign]
    campaign.script = Script.active.find_by_user_id(@user.id) unless campaign.script
    campaign.voter_lists.disable_all
    campaign.voter_lists.by_ids(params[:voter_list_ids]).enable_all
    campaign.save
    flash_message(:notice, "Campaign saved")

    if campaign.caller_id.present? and (not campaign.caller_id_verified)
      validation_code = campaign.caller_id_object.validation_code
      if validation_code
        flash_message(:notice, "<font color=red>Please enter code #{validation_code} when called.</font>")
      else
        flash_message(:error, "Could not validate your caller id")
      end
    end

    redirect_to campaign_path(campaign)
  end

  def index
    @campaigns = @user.campaigns.active.paginate :page => params[:page], :order => 'id desc'
  end

  def show
    begin
      @campaign = @user.campaigns.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound => e
      render :text => "Permission denied", :status => 550 and return
    end
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
