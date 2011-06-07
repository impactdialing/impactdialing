module Admin
  class CampaignsController < AdminController
    def index
      @campaigns = Campaign.by_updated.paginate(:per_page => 20, :page => params[:page])
    end

    def restore
      Campaign.find(params[:campaign_id]).tap do |c|
        c.restore
        c.save
      end
      redirect_to admin_campaigns_path
    end
  end
end
