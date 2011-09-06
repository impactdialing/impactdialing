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

  it "asks for the campaign context" do
    caller = Factory(:caller)
    session = Factory(:caller_session, :caller => caller)
    session.ask_for_campaign.should == Twilio::Verb.new do |v|
      v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(session, :host => Settings.host, :attempt => 1), :method => "POST") do
        v.say "Please enter your campaign id."
      end
    end.response
  end

  it "asks for campaign pin context again" do
    caller = Factory(:caller)
    session = Factory(:caller_session, :caller => caller)
    session.ask_for_campaign(1).should == Twilio::Verb.new do |v|
      v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(session, :host => Settings.host, :attempt => 2), :method => "POST") do
        v.say "Incorrect campaign Id. Please enter your campaign Id."
      end
    end.response
  end

  it "hangs up on three incorrect campaign contexts" do
    caller = Factory(:caller)
    session = Factory(:caller_session, :caller => caller)
    session.ask_for_campaign(3).should == Twilio::Verb.new do |v|
      v.say "Incorrect campaign Id."
      v.hangup
    end.response
  end
end
