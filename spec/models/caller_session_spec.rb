require "spec_helper"

describe CallerSession do
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
end
