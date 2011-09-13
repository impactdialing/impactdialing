require "spec_helper"

describe Callers::CampaignsController do
  let(:user) { Factory(:user) }
  let(:caller) { Factory(:caller, :user => user) }
  let(:campaign) { Factory(:campaign, :user => user) }

  before(:each) do
    login_as(caller)
  end

  it "lists all active campaigns with a web ui" do
    user.campaigns << Factory(:campaign, :active => false)
    user.campaigns << Factory(:campaign, :active => false, :use_web_ui => true)
    user.campaigns << Factory(:campaign, :active => true, :use_web_ui => false)
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    user.campaigns << campaign1
    caller.save
    get :index
    assigns(:campaigns).should == [campaign1]
  end

  it "finds a callers campaign" do
    user.campaigns << Factory(:campaign, :active => false)
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    user.campaigns << campaign1
    caller.save
    get :show, :id => campaign1.id
    assigns(:campaign).should == campaign1
  end

  #it "allows a caller to callin to a campaign" do
  #  #login_as(caller)
  #  Caller.stub(:find).and_return(caller)
  #  sid = "sid"
  #  TwilioClient.stub_chain(:instance, :account, :calls, :create).and_return({"TwilioResponse" => {"Call" => {"Sid" => sid}}})
  #  post :callin, :id => campaign.id, :caller => {:phone => '39465987345'}
  #  session = assigns(:session)
  #  session.campaign.should == campaign
  #  session.sid.should == sid
  #  session.available_for_call.should == false
  #  session.on_call.should == false
  #end

  it "receives caller ready callback from twilio" do
    login_as(caller)
    session = Factory(:caller_session, :caller => caller, :sid => "sid")
    CallerSession.stub(:find_by_sid).and_return(session)
    post :caller_ready, :id => campaign.id, :caller_id => caller.id, :caller_sid => session.sid
    session.on_call.should be_true
    session.available_for_call.should be_true
  end


end
