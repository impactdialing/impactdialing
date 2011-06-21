module Client
  class CampaignsController < ClientController
    def deleted
      @campaigns = Campaign.deleted.for_user(@user).paginate :page => params[:page], :order => 'id desc'
    end

    def restore
      Campaign.find(params[:campaign_id]).tap do |c|
        c.restore
        c.save
      end
      redirect_to :back
    end

    def create
      @user.campaigns.create!(:script => @user.scripts.first)
    end
  end
end
