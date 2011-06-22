require "spec_helper"

describe Client::CampaignsController do
  let(:user) {Factory(:user)}

  before(:each) do
    login_as user
  end

  it "creates a new campaign" do
    lambda {
      post :create
    }.should change{user.reload.campaigns.size}.by 1
  end

  it "assigns some script on that user on the new campaign" do
    script = Factory(:script, :user => user)
    post :create
    user.reload.campaigns.last.script.should == script
  end

  it "leaves the script nil if the user has none" do
    post :create
    user.reload.campaigns.last.script.should be_nil
  end

  it "defaults the predective_type to algorithm1" do
    post :create
    user.reload.campaigns.last.predective_type.should == 'algorithm1'
  end

  it "redirects to show after creation" do
    post :create
    response.should redirect_to(campaign_path(user.reload.campaigns.last))
  end
end
