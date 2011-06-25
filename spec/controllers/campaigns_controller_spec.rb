require "spec_helper"

describe CampaignsController do
  let(:user) { Factory(:user) }
  let(:another_users_campaign) { Factory(:campaign, :user => Factory(:user)) }


  before(:each) do
    login_as user
  end

  it "renders a campaign" do
    get :show, :id => Factory(:campaign, :user => user).id
    response.code.should == '200'
  end

  describe "create a campaign" do
    it "creates a campaign" do
      lambda { post :create }.should change(Campaign, :count)
      response.should redirect_to(campaign_path(Campaign.first))
    end
    it "adds the user's existing active callers to the campaign" do
      Factory(:caller, :user => user, :active => false)
      active_callers = [Factory(:caller, :user => user, :active => true), Factory(:caller, :user => user, :active => true)]
      post :create
      Campaign.count.should == 1
      Campaign.first.callers.should == active_callers
    end
  end

  describe "update a campaign" do
    let(:campaign) { Factory(:campaign, :user => user) }
    it "updates the campaign attributes" do
      post :update, :id => campaign.id, :campaign => {:name => "an impactful campaign"}
      campaign.reload.name.should == "an impactful campaign"
    end
    it "assigns one of the scripts of the current user" do
      script = Factory(:script, :user => user)
      post :update, :id => campaign.id, :campaign => {}
      campaign.reload.script.should == script
    end
    it "validates the caller id" do
      phone_number = "1234567890"
      validation_code = "xyzzyspoonshift1"
      caller_id_object = mock
      caller_id_object.should_receive(:validation_code).and_return("xyzzyspoonshift1")
      campaign.stub!(:caller_id_object).and_return(caller_id_object)
      Campaign.should_receive(:find).with(campaign.id, anything).and_return(campaign)
      post :update, :id => campaign.id, :campaign => {:name => "an impactful campaign", :caller_id => phone_number}
      flash[:notice].join.should include validation_code
    end
    it "can update only campaigns owned by the user'" do
      post :update, :id => another_users_campaign.id
      response.code.should == '550'
    end
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
