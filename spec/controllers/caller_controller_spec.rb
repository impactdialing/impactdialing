require "spec_helper"

describe CallerController do
  describe 'index' do
    let(:caller) { Factory(:caller) }
    before(:each) do
      login_as(caller)
    end

    it "doesn't list deleted campaigns" do
      caller.campaigns = [(Factory(:campaign, :active => false)), Factory(:campaign, :active => true) ]
      caller.save!
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end

    it "lists all campaigns for web ui" do
      Factory(:campaign, :use_web_ui => false)
      campaign = Factory(:campaign, :use_web_ui => true)
      caller.update_attribute(:campaigns, [campaign])
      get :index
      assigns(:campaigns).should == [campaign]
    end
  end

  describe "preview dial" do

    it "connects to twilio before making a call" do
      session_key = "sdklsjfg923784"
      caller = Factory(:caller)
      login_as(caller)
      session = Factory(:caller_session, :caller=> caller, :session_key => session_key)
      CallerSession.stub(:find_by_session_key).with(session_key).and_return(session)
      session.stub(:call)
      Twilio.should_receive(:connect).with(anything, anything)
      get :preview_dial, :key => session_key, :voter_id => Factory(:voter).id
    end

  end

  it "allocates a campaign to a caller calling in" do
    user = Factory(:user)
    caller = Factory(:caller, :user => user)
    pin = '1234'
    campaign = Factory(:campaign, :campaign_id => pin, :user => user)
    session = Factory(:caller_session, :caller => caller, :campaign => nil)
    CallerSession.stub(:find).and_return(session)
    session.stub(:start).and_return(:nothing)

    post :assign_campaign, :session_id => session, :Digits => pin
    assigns(:session).campaign.should == campaign
  end

  it "creates a conference for a caller calling in" do
    user = Factory(:user)
    caller = Factory(:caller, :user => user)
    pin = '1234'
    campaign = Factory(:campaign, :campaign_id => pin, :user => user)
    session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')

    post :assign_campaign, :session => session.id, :Digits => pin
    response.body.should == session.start
  end

  it "asks for campaign pin again when incorrect" do
    user = Factory(:user)
    caller = Factory(:caller, :user => user)
    campaign = Factory(:campaign, :user => user)
    session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')

    post :assign_campaign, :session => session.id, :Digits => '1234', :attempt => 1
    response.body.should == session.ask_for_campaign(1)
  end

  it "does not allow a caller from one user to log onto a campaign of another user" do
    user = Factory(:user)
    caller = Factory(:caller, :user => user)
    cpin = '1234'
    Factory(:campaign, :user => Factory(:user), :campaign_id => cpin)
    session = Factory(:caller_session, :caller => caller, :session_key => 'key')
    post :assign_campaign, :session => session.id, :Digits => '1234', :attempt => 1
    response.body.should == session.ask_for_campaign(1)
  end



end
