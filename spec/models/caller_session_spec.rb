require "spec_helper"

describe CallerSession do
  include Rails.application.routes.url_helpers

  it "lists active callers" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
  end

  it "lists callers with hold for duration" do
    Factory(:caller_session, :on_call=> false, :hold_time_start=> Time.now)
    Factory(:caller_session, :on_call=> true, :hold_time_start=> Time.now)
    call3 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 3.minutes.ago)
    call4 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 6.minutes.ago)
    CallerSession.held_for_duration(3.minutes).should == [call3,call4]
  end

  it "lists available caller sessions" do
    call1 = Factory(:caller_session, :available_for_call=> true, :on_call=>true)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    Factory(:caller_session, :available_for_call=> true, :on_call=>false)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    CallerSession.available.should == [call1]
  end

  it "calls a voter" do
    voter = Factory(:voter, :campaign => Factory(:campaign, :predictive_type => 'algorithm1'))
    session = Factory(:caller_session, :available_for_call => true, :on_call => false)
    Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
    voter.should_receive(:dial_predictive)
    session.call(voter)
    voter.caller_session.should == session
  end

  describe "Calling in" do
    let(:caller){ Factory(:caller) }

    it "asks for the campaign context" do
      session = Factory(:caller_session, :caller => caller)
      session.ask_for_campaign.should == Twilio::Verb.new do |v|
        v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(session.caller, :session => session, :host => Settings.host, :attempt => 1), :method => "POST") do
          v.say "Please enter your campaign id."
        end
      end.response
    end

    it "asks for campaign pin context again" do
      session = Factory(:caller_session, :caller => caller)
      session.ask_for_campaign(1).should == Twilio::Verb.new do |v|
        v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(session.caller, :session => session, :host => Settings.host, :attempt => 2), :method => "POST") do
          v.say "Incorrect campaign Id. Please enter your campaign Id."
        end
      end.response
    end

    it "hangs up on three incorrect campaign contexts" do
      session = Factory(:caller_session, :caller => caller)
      session.ask_for_campaign(3).should == Twilio::Verb.new do |v|
        v.say "Incorrect campaign Id."
        v.hangup
      end.response
    end

    it "creates a conference" do
      campaign, conf_key = Factory(:campaign), "conference_key"
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => conf_key)
      session.start.should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true, :action => end_session_caller_url(caller, :host => Settings.host, :session => session, :campaign => campaign)) do
          v.conference(conf_key, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => "GET")
        end
      end.response
      session.on_call.should be_true
      session.available_for_call.should be_true
    end

    it "terminates a conference" do
      campaign, conf_key = Factory(:campaign), "conference_key"
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => conf_key)
      time_now = Time.now
      Time.stub(:now).and_return(time_now)
      session.end
      session.available_for_call.should be_false
      session.on_call.should be_false
      session.endtime.should == time_now
    end
  end

  describe "preview dialing" do
    let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'preview') }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:caller) { Factory(:caller) }

    it "dials a voter for a caller session" do
      caller_session = Factory(:caller_session, :campaign => campaign, :caller => caller)
      call_attempt = Factory(:call_attempt, :campaign => campaign, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session)
      voter.stub_chain(:call_attempts,:create).and_return(call_attempt)
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, connect_call_attempt_url(call_attempt, :host => Settings.host), anything)
      caller_session.preview_dial(voter)
      voter.caller_session.should == caller_session
      call_attempt.sid.should == "sid"
    end

  end

  describe "pusher" do
    let(:caller){ Factory(:caller) }

    it "publishes information to a caller in session" do
      campaign = Factory(:campaign, :use_web_ui => true)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      event,data = 'event','data'
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with(event,data)
      session.publish(event,data)
    end

    it "does not publish information to a caller not using web ui" do
      campaign = Factory(:campaign, :use_web_ui => false)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      event,data = 'event','data'
      Pusher.should_not_receive(:[])
      session.publish(event,data)
    end

    it "pushes voter data being called by a caller" do
      campaign = Factory(:campaign, :use_web_ui => true)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      voter = Factory(:voter, :campaign => campaign, :caller_session => session)
      voter.stub(:dial_predictive)
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("calling",voter.info)
      session.call(voter)
    end

    it "pushes voter information when a caller is connected on preview campaign" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      2.times{Factory(:voter, :campaign => campaign)}
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("caller_connected",anything)
      session.start
    end

    it "should not push anything when a caller is connected on a non preview campaign" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'predictive')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      2.times{Factory(:voter, :campaign => campaign)}
      Pusher.should_not_receive(:[]).with(session.session_key)
      session.start
    end

    it "should push 'caller_disconnected' when the caller session ends" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample", :on_call=> true, :available_for_call => true)
      2.times{Factory(:voter, :campaign => campaign)}
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("caller_disconnected",anything)
      session.end
    end
  end
end
