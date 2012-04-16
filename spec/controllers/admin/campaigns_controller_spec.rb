require "spec_helper"

describe Admin::CampaignsController do
  before(:each) do
    controller.should_receive(:authenticate).and_return(true)
  end

  it "restores a deleted campaign" do
    campaign = Factory(:preview, :active => false)
    put :restore, :campaign_id => campaign.id
    campaign.reload.should be_active
    response.should redirect_to admin_campaigns_path
  end
end
