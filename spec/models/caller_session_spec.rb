require "spec_helper"

describe CallerSession do
  it "lists active callers" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
    end

  it "lists idle callers" do
    call1 = Factory(:caller_session, :on_call=> false)
    call2 = Factory(:caller_session, :on_call=> true)
    call3 = Factory(:caller_session, :on_call=> false)
    CallerSession.not_on_call.should =~ [call1, call3]
  end

  it "lists available callers" do
    call1 = Factory(:caller_session, :available_for_call=> true)
    call2 = Factory(:caller_session, :available_for_call=> false)
    call3 = Factory(:caller_session, :available_for_call=> true)
    CallerSession.available.should == [call1, call3]
  end

  it "lists callers with hold for duration" do
    Factory(:caller_session, :on_call=> false, :hold_time_start=> Time.now)
    Factory(:caller_session, :on_call=> true, :hold_time_start=> Time.now)
    call3 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 3.minutes.ago)
    call4 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 6.minutes.ago)
    CallerSession.held_for_duration(3.minutes).should == [call3,call4]
  end
end