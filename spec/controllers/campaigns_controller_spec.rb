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
      @campaign = Factory(:campaign, :user => user, :caller_id => "1234567890")
    end
    it "should render 'not verified' if caller id not verified" do
      invalid_caller_id_object = mock
      invalid_caller_id_object.should_receive(:validate).and_return(false)
      Campaign.should_receive(:find).with(@campaign.id, anything).and_return(@campaign)
      @campaign.stub!(:caller_id_object).and_return(invalid_caller_id_object)
      post :verify_callerid, :id => @campaign.id
      response.body.should include "not verified"
    end
    it "should render nothing if caller id is verified" do
      valid_caller_id_object = mock
      valid_caller_id_object.should_receive(:validate).and_return(true)
      Campaign.should_receive(:find).with(@campaign.id, anything).and_return(@campaign)
      @campaign.stub!(:caller_id_object).and_return(valid_caller_id_object)
      post :verify_callerid, :id => @campaign.id
      response.body.should be_blank
    end
    it "can verify caller id only for campaigns owned by the user'" do
      post :verify_callerid, :id => another_users_campaign.id
      response.code.should == '550'
    end
  end

  def type_name
    'campaign'
  end

  it_should_behave_like 'all controllers of deletable entities'
end
