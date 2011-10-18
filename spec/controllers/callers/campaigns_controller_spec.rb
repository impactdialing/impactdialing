require "spec_helper"

describe Callers::CampaignsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:caller) { Factory(:caller, :account => account) }
  let(:campaign) { Factory(:campaign, :account => account) }

  before(:each) do
    login_as(caller)
  end

  it "lists all manual active campaigns with a web ui" do
    account.campaigns << Factory(:campaign, :active => false)
    account.campaigns << Factory(:campaign, :active => false,:robo => false, :use_web_ui => true)
    account.campaigns << Factory(:campaign, :active => true, :robo => false, :use_web_ui => false)
    account.campaigns << Factory(:campaign, :active => true, :robo => true, :use_web_ui => true)
    campaign1 = Factory(:campaign, :active => true, :robo => false, :use_web_ui => true)
    account.campaigns << campaign1
    caller.save
    get :index
    assigns(:campaigns).should == [campaign1]
  end

  it "finds a callers campaign" do
    account.campaigns << Factory(:campaign, :active => false)
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    account.campaigns << campaign1
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
