require "spec_helper"

describe CampaignsController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  it "renders a campaign" do
    get :show, :id => Factory(:campaign, :user => user).id
    response.code.should == '200'
  end

  it "creates a campaign" do
    lambda { post :create }.should change(Campaign, :count)
  end

  it "updates a campaign" do
    campaign = Factory(:campaign)
    post :update, :id => campaign.id, :campaign => {:name => "an impactful campaign"}
    campaign.reload.name.should == "an impactful campaign"
  end

  describe "caller id verification" do
    before :each do
      @campaign = Factory(:campaign, :user => user)
      @campaign.stub(:check_valid_caller_id)
      @campaign.update_attributes(:caller_id => "1234567890")
      Campaign.stub!(:find, @campaign.id).and_return(@campaign)
    end
    
    it "verifies caller id" do
      @campaign.should_receive(:check_valid_caller_id_and_save)
      post :verify_callerid, :id => @campaign.id
    end
    it "should render 'not verified' if caller id not verified" do
      @campaign.stub(:check_valid_caller_id).and_return(false)
      post :verify_callerid, :id => @campaign.id
      response.body.should include "not verified"
    end
    it "should render nothing if caller id is verified" do
      @campaign.stub!(:caller_id_verified).and_return(true)
      post :verify_callerid, :id => @campaign.id
      response.body.should be_blank
    end
  end
end
