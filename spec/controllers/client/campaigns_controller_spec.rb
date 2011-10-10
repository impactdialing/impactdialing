require "spec_helper"

describe Client::CampaignsController do
  let(:user) { Factory(:user, :paid => true) }

  before(:each) do
    login_as user
  end

  it "lists active manual campaigns" do
    robo_campaign = Factory(:campaign, :user => user, :robo => true, :active => true)
    manual_campaign = Factory(:campaign, :user => user, :robo => false, :active => true)
    inactive_campaign = Factory(:campaign, :user => user, :robo => false, :active => false)
    get :index
    assigns(:campaigns).should == [manual_campaign]
  end

  describe 'show' do
    let(:campaign) {Factory(:campaign, :user => user, :caller_id => 'foo')}

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
      unverified_campaign = Factory(:campaign, :user => user, :caller_id => nil)
      get :show, :id => unverified_campaign.id
      flash[:warning].should include("When you make calls with this campaign, you need a phone number to use for the Caller ID. Enter the phone number you want to use for your Caller ID and click Verify. To prevent abuse, the system will call that number and ask you to enter a validation code that will appear on your screen. Until you do this, you can't make calls with this campaign.")
    end

    after(:each) do
      response.should be_ok
    end
  end

  it "deletes campaigns" do
    request.env['HTTP_REFERER'] = 'http://referer'
    campaign = Factory(:campaign, :user => user, :active => true, :robo => false)
    delete :destroy, :id => campaign.id
    campaign.reload.should_not be_active
    response.should redirect_to 'http://referer'
  end


  it "creates a new campaign" do
    pending "failing test after merge with client rewrite."
    script = Factory(:script, :user => user)
    callers = 3.times.map{Factory(:caller, :user => user)}
    lambda {
      post :create
    }.should change {user.reload.campaigns.size} .by(1)
    campaign = user.campaigns.last
    campaign.predictive_type.should == 'algorithm1'
    campaign.script.should == script
    campaign.callers.should == callers
  end
end
