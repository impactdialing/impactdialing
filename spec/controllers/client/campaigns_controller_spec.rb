require "spec_helper"

describe Client::CampaignsController do
  let(:user) { Factory(:user) }
  let(:account) { user.account }

  before(:each) do
    login_as user
  end

  it "only an admin clears calls" do
    login_as (admin_user = Factory(:admin_user))
    campaign = Factory(:campaign, :account => admin_user.account)
    voter = Factory(:voter, :campaign => campaign, :result => 'foo', :status => 'bar')
    put :clear_calls, :campaign_id => campaign.id
    voter.reload
    voter.result.should be_nil
    voter.status.should == 'not called'
    response.should redirect_to(client_campaign_path(campaign))
  end

  it "a non admin can't clear calls" do
    campaign = Factory(:campaign, :account => account)
    voter = Factory(:voter, :campaign => campaign, :result => 'foo', :status => 'bar')
    put :clear_calls, :campaign_id => campaign.id
    voter.reload
    voter.result.should == 'foo'
    voter.status.should == 'bar'
    response.code.should == '401'
  end

  it "creates a new robo campaign" do
    manual_script = Factory(:script, :account => account, :robo => false)
    robo_script = Factory(:script, :account => account, :robo => true)
    lambda {
      post :create
    }.should change(user.account.campaigns.active.manual, :size).by(1)
    user.account.campaigns.active.manual.last.script.should == manual_script
    response.should redirect_to client_campaign_path(user.account.campaigns.last)
  end

  it "redirects to robo campaign page if it's a robo campaign" do
    robo_campaign = Factory(:campaign, :robo => true, :account => account)
    get :show, :id => robo_campaign.id
    response.should redirect_to(broadcast_campaign_path(robo_campaign))
  end
end
