require "spec_helper"

describe CampaignsController do
  let(:user) { Factory(:user) }
  before(:each) do
    login_as user
  end
  it "renders a campaign" do
    get :show, :id => Factory(:campaign, :user => user).id
    response.should be_ok
  end
end
