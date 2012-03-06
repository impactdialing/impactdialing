require "spec_helper"

describe Client::CampaignsController do
  let(:account) { Factory(:account, :activated => true) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as user
  end

  it "lists active manual campaigns" do
    robo_campaign = Factory(:campaign, :account => account, :robo => true, :active => true)
    manual_campaign = Factory(:campaign, :account => account, :robo => false, :active => true)
    inactive_campaign = Factory(:campaign, :account => account, :robo => false, :active => false)
    get :index
    assigns(:campaigns).should == [manual_campaign]
  end

  describe 'show' do
    let(:campaign) {Factory(:campaign, :account => account)}


    after(:each) do
      response.should be_ok
    end
  end

  it "deletes campaigns" do
    request.env['HTTP_REFERER'] = 'http://referer'
    campaign = Factory(:campaign, :account => account, :active => true, :robo => false)
    delete :destroy, :id => campaign.id
    campaign.reload.should_not be_active
    response.should redirect_to 'http://referer'
  end

  it "restore campaigns" do
    request.env['HTTP_REFERER'] = 'http://referer'
    campaign = Factory(:campaign, :account => account, :active => true, :robo => false)
    put :restore, :campaign_id => campaign.id
    campaign.reload.should be_active
    response.should redirect_to 'http://referer'
  end

  it "creates a new campaign" do
    script = Factory(:script, :account => account)
    callers = 3.times.map{Factory(:caller, :account => account)}
    lambda {
      post :create , :campaign => {:caller_id => '0123456789'}
    }.should change {account.reload.campaigns.size} .by(1)
    campaign = account.campaigns.last
    campaign.predictive_type.should == 'preview'
    campaign.script.should == script
    campaign.account.callers.should == callers
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
      post :create , :campaign => {:caller_id => '0123456789'}
    }.should change(user.account.campaigns.active.manual, :size).by(1)
    user.account.campaigns.active.manual.last.script.should == manual_script
    response.should redirect_to client_campaigns_path
  end

  it "redirects to robo campaign page if it's a robo campaign" do
    robo_campaign = Factory(:campaign, :robo => true, :account => account)
    get :show, :id => robo_campaign.id
    response.should redirect_to(broadcast_campaign_path(robo_campaign))
  end
end
