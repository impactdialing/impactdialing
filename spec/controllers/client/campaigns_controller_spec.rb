require "spec_helper"

describe Client::CampaignsController do
  let(:account) { Factory(:account, :paid => true) }
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
    let(:campaign) {Factory(:campaign, :account => account, :caller_id => 'foo')}

    it "lists the campaign's active voters" do
      inactive_voter = Factory(:voter, :active => false, :campaign => campaign)
      active_voter = Factory(:voter, :active => true, :campaign => campaign)
      get :show, :id => campaign.id
      assigns(:voters).should == [active_voter]
    end

    it "orders the campaign's voters by LastName, FirstName & Phone" do
      Factory(:voter, :active => true, :campaign => campaign, :FirstName => '1', :LastName => 'b', :Phone => '3333333333')
      Factory(:voter, :active => true, :campaign => campaign, :FirstName => '1', :LastName => 'b', :Phone => '0000000000')
      Factory(:voter, :active => true, :campaign => campaign, :FirstName => '2', :LastName => 'a', :Phone => '2222222222')
      Factory(:voter, :active => true, :campaign => campaign, :FirstName => '1', :LastName => 'a', :Phone => '1111111111')
      get :show, :id => campaign.id
      assigns(:voters).map(&:Phone).should == ['1111111111', '2222222222', '0000000000', '3333333333']
    end

    it "warns the user if there is no caller id" do
      unverified_campaign = Factory(:campaign, :account => account, :caller_id => nil)
      get :show, :id => unverified_campaign.id
      flash[:warning].should include("When you make calls with this campaign, you need a phone number to use for the Caller ID. Enter the phone number you want to use for your Caller ID and click Verify. To prevent abuse, the system will call that number and ask you to enter a validation code that will appear on your screen. Until you do this, you can't make calls with this campaign.")
    end

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

  it "creates a new campaign" do
    script = Factory(:script, :account => account)
    callers = 3.times.map{Factory(:caller, :account => account)}
    lambda {
      post :create
    }.should change {account.reload.campaigns.size} .by(1)
    campaign = account.campaigns.last
    campaign.predictive_type.should == 'algorithm1'
    campaign.script.should == script
    campaign.callers.should == callers
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
