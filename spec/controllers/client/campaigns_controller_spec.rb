require "spec_helper"

describe Client::CampaignsController do
  let(:account) { Factory(:account, :activated => true) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as user
  end

  it "lists active manual campaigns" do
    robo_campaign = Factory(:robo, :account => account, :active => true)
    manual_campaign = Factory(:preview, :account => account, :active => true)
    inactive_campaign = Factory(:progressive, :account => account, :active => false)
    get :index
    assigns(:campaigns).should == [manual_campaign]
  end

  describe 'show' do
    let(:campaign) {Factory(:preview, :account => account)}


    after(:each) do
      response.should be_ok
    end
  end

  it "deletes campaigns" do
    request.env['HTTP_REFERER'] = 'http://referer'
    campaign = Factory(:preview, :account => account, :active => true)
    delete :destroy, :id => campaign.id
    campaign.reload.should_not be_active
    response.should redirect_to 'http://referer'
  end

  it "restore campaigns" do
    request.env['HTTP_REFERER'] = 'http://referer'
    campaign = Factory(:preview, :account => account, :active => true, :robo => false)
    put :restore, :campaign_id => campaign.id
    campaign.reload.should be_active
    response.should redirect_to 'http://referer'
  end

  it "creates a new campaign" do
    script = Factory(:script, :account => account)
    callers = 3.times.map{Factory(:caller, :account => account)}
    lambda {
      post :create , :campaign => {:caller_id => '0123456789', type: "Preview", name: "campaign 1", script_id: script.id}
    }.should change {account.reload.campaigns.size} .by(1)
    campaign = account.campaigns.last
    campaign.type.should == 'Preview'
    campaign.script.should == script
    campaign.account.callers.should == callers
  end
end
