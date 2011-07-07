require "spec_helper"

describe CallAttempt do

  it "lists all attempts for a campaign" do
    campaign = Factory(:campaign)
    attempt_of_our_campaign = Factory(:call_attempt, :campaign => campaign)
    attempt_of_another_campaign = Factory(:call_attempt, :campaign => Factory(:campaign))
    CallAttempt.for_campaign(campaign).to_a.should =~ [attempt_of_our_campaign]
  end

  it "lists all attempts by status" do
    delivered_attempt = Factory(:call_attempt, :status => "Message delivered")
    successful_attempt = Factory(:call_attempt, :status => "Call completed with success.")
    CallAttempt.for_status("Message delivered").to_a.should =~ [delivered_attempt]
  end

  it "rounds up the duration to the nearest minute" do
    now = Time.now
    call_attempt = Factory(:call_attempt, :call_start => now, :call_end => now + 2.minutes + 30.seconds)
    call_attempt.duration_rounded_up.should == 3
  end

  it "rounds up the duration up to now if the call is still running" do
    now = Time.now
    call_attempt = Factory(:call_attempt, :call_start => now, :call_end => nil)
    Time.stub(:now).and_return(now + 1.minute + 30.seconds)
    call_attempt.duration_rounded_up.should == 2
  end

  it "reports 0 minutes if the call hasn't even started" do
    call_attempt = Factory(:call_attempt, :call_start => nil, :call_end => nil)
    call_attempt.duration_rounded_up.should == 0
  end
end
