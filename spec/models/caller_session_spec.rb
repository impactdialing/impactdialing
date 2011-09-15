require "spec_helper"

describe CallerSession do
  it "lists active calls" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
  end

  it "lists attempts between two dates" do
    too_old = Factory(:caller_session).tap{|ca| ca.update_attribute(:created_at, 10.minutes.ago)}
    too_new = Factory(:caller_session).tap{|ca| ca.update_attribute(:created_at, 10.minutes.from_now)}
    just_right = Factory(:caller_session).tap{|ca| ca.update_attribute(:created_at, 8.minutes.ago)}
    another_just_right = Factory(:caller_session).tap{|ca| ca.update_attribute(:created_at, 8.minutes.from_now)}
    CallerSession.between(9.minutes.ago, 9.minutes.from_now)
  end
end
