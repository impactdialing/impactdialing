require "spec_helper"

describe CallerSession do
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
end