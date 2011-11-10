require "spec_helper"

describe CallerController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:caller) { Factory(:caller, :account => account) }

  describe 'index' do
    before(:each) do
      login_as(caller)
    end

    it "doesn't list deleted campaigns" do
      caller.campaigns = [(Factory(:campaign, :active => false)), Factory(:campaign, :active => true)]
      caller.save!
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end

    it "doesn't list robo campaigns" do
      caller.campaigns = [(Factory(:campaign, :active => true, :robo => false)), Factory(:campaign, :active => true, :robo => true)]
      caller.save!
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end

    it "lists all campaigns for web ui" do
      Factory(:campaign, :use_web_ui => false)
      campaign = Factory(:campaign, :use_web_ui => true)
      caller.campaigns << campaign
      caller.save!
      get :index
      assigns(:campaigns).should eq([campaign])
    end
  end

  describe "preview dial" do
    let(:campaign) { Factory(:campaign) }

    before(:each) do
      login_as(caller)
    end

    it "pushes a preview voter to the caller" do
      session_key = "sdklsjfg923784"
      voter = Factory(:voter, :campaign => campaign)
      next_voter = Factory(:voter, :campaign => campaign)
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', voter.info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id
    end

    it "connects to twilio before making a call" do
      session_key = "sdklsjfg923784"
      session = Factory(:caller_session, :caller=> caller, :session_key => session_key)
      CallerSession.stub(:find_by_session_key).with(session_key).and_return(session)
      session.stub(:call)
      Twilio.should_receive(:connect).with(anything, anything)
      get :preview_dial, :key => session_key, :voter_id => Factory(:voter).id
    end

    it "skips to the next voter to preview" do
      session_key = "sdklsjfg923784"
      voter = Factory(:voter, :campaign => campaign, "FirstName"=>'first')
      next_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'last')
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', next_voter.info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id, :voter_id => voter.id
    end

    it "skips to the first undialed voter if the current voter context is the last" do
      session_key = "sdklsjfg923784"
      first_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'first')
      last_voter = Factory(:voter, :campaign => campaign, "FirstName"=>'last')      
      session = Factory(:caller_session, :campaign => campaign, :caller => caller, :session_key => session_key)
      channel = mock
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('caller_connected', first_voter.info.merge(:dialer => campaign.predictive_type))
      post :preview_voter, :id => caller.id, :session_id => session.id, :voter_id => last_voter.id
    end

    it "makes a call to the voter" do
      caller_session = Factory(:caller_session, :caller => caller, :on_call => true, :available_for_call => true)
      voter = Factory(:voter)
      Twilio::Call.stub(:make)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone,anything,anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      post :call_voter, :session_id => caller_session.id , :voter_id => voter.id
    end

    it "pushes 'calling' to the caller" do
      session_key = "caller_session_key"
      caller_session = Factory(:caller_session, :caller => caller, :on_call => true, :available_for_call => true, :session_key => session_key)
      voter = Factory(:voter)
      Twilio::Call.stub(:make).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      channel = mock
      Pusher.should_receive(:[]).with(session_key).and_return(channel)
      channel.should_receive(:trigger).with('calling_voter', anything)
      post :call_voter, :session_id => caller_session.id , :voter_id => voter.id
    end
  end

  describe "calling in" do
    it "allocates a campaign to a caller" do
      campaign = Factory(:campaign, :account => account)
      session = Factory(:caller_session, :caller => caller, :campaign => nil)
      CallerSession.stub(:find).and_return(session)
      session.stub(:start).and_return(:nothing)

      post :assign_campaign, :session_id => session, :Digits => campaign.reload.campaign_id
      assigns(:session).campaign.should == campaign
    end

    it "creates a conference for a caller" do
      campaign = Factory(:campaign, :account => account)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')

      post :assign_campaign, :session => session.id, :Digits => campaign.reload.campaign_id
      response.body.should == session.start
    end

    it "asks for campaign pin again when incorrect" do
      campaign = Factory(:campaign, :account => account)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => 'key')

      post :assign_campaign, :session => session.id, :Digits => '1234', :attempt => 1
      response.body.should == session.ask_for_campaign(1)
    end

    it "does not allow a caller from one user to log onto a campaign of another user" do
      cpin = '1234'
      Factory(:campaign, :account => Factory(:account), :campaign_id => cpin)
      session = Factory(:caller_session, :caller => caller, :session_key => 'key')
      post :assign_campaign, :session => session.id, :Digits => '1234', :attempt => 1
      response.body.should == session.ask_for_campaign(1)
    end

    it "terminates a callers session" do
      sid = "some_sid"
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => true, :on_call => true, :sid => sid)
      post :end_session, :CallSid => sid
      session.reload.available_for_call.should be_false
      session.reload.on_call.should be_false
      response.body.should == Twilio::Verb.hangup
    end

    it "pauses a callers session while an attempt is in progress" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => true, :voter_in_progress => Factory(:voter), :session_key => 'some_key')
      post :pause, :id => caller.id, :session_id => session.id, :attempt => nil
      response.body.should == session.pause_for_results
    end

    it "says wait message every fifth attempts when the voter is paused for results" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => true, :voter_in_progress => Factory(:voter), :session_key => 'some_key')
      post :pause, :id => caller.id, :session_id => session.id, :attempt => 5
      response.body.should == session.pause_for_results(5)
    end

    it "resets a callers session's conference while an attempt is in progress" do
      session = Factory(:caller_session, :caller => caller, :campaign => Factory(:campaign), :available_for_call => false, :on_call => true, :session_key => "some_key")
      post :pause, :id => caller.id, :session_id => session.id
      response.body.should == session.start
    end

    it "finds the campaigns callers active session" do
      login_as(caller)
      campaign = Factory(:campaign)
      Factory(:caller_campaign,:caller => caller, :campaign => campaign)
      session = Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => true, :available_for_call => true, :campaign => campaign)
      Factory(:caller_session, :caller => caller, :session_key => 'other_key', :on_call => true, :available_for_call => true, :campaign => Factory(:campaign))
      post :active_session, :id => caller.id, :campaign_id => campaign
      response.body.should == session.to_json
    end

    it "returns no session if the caller is not connected" do
      login_as(caller)
      campaign = Factory(:campaign)
      Factory(:caller_campaign, :caller => caller, :campaign => campaign)
      Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => false, :available_for_call => true, :campaign => campaign)
      post :active_session, :id => caller.id, :campaign_id => campaign.id
      response.body.should == {:caller_session => {:id => nil}}.to_json
    end
  end

  it "logs out" do
    login_as(caller)
    post :logout
    session[:caller].should_not be
    response.should redirect_to(caller_root_path)
  end
end
