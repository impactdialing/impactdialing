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
      campaign = @user.campaigns.create!(:script => @user.scripts.first, :predective_type => 'algorithm1')
      redirect_to campaign_path(campaign)
    end
  end
