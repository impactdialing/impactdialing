require "spec_helper"

describe Broadcast::CampaignsController do
  let(:user) { Factory(:user) }
  let(:account) { user.account }

  before(:each) { login_as user }

  it "redirects to manual campaign page if it's a manual campaign" do
    manual_campaign = Factory(:preview, :account => account)
    get :show, :id => manual_campaign.id
    response.should redirect_to(client_campaign_path(manual_campaign))
  end
end
