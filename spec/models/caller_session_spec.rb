require "spec_helper"

describe CallerSession do
  include Rails.application.routes.url_helpers

  it "lists active calls" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
  end

  it "lists available caller sessions" do
    call1 = Factory(:caller_session, :available_for_call=> true, :on_call=>true)
    call2 = Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    call3 = Factory(:caller_session, :available_for_call=> true, :on_call=>false)
    call4 = Factory(:caller_session, :available_for_call=> false, :on_call=>false)
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
      channel.should_receive(:trigger).with("calling",voter.to_json)
      session.call(voter)
    end


  end

end
