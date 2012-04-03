require "spec_helper"

describe Callers::CampaignsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:campaign) { Factory(:campaign, :account => account) }
  let(:caller) { Factory(:caller, :account => account, :campaign => campaign) }
  

  before(:each) do
    login_as(caller)
  end

  it "finds a callers campaign" do
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    caller_session = Factory(:caller_session, caller: caller)
    get :show, id:  campaign1.id, caller_session: caller_session
    assigns(:campaign).should == campaign
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
