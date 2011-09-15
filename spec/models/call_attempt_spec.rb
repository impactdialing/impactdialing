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

  describe 'next recording' do
    let(:script) {Factory(:script)}
    let(:campaign) {Factory(:campaign, :script => script)}
    let(:call_attempt) {Factory(:call_attempt, :campaign => campaign)}

    before(:each) do
      @recording1 = Factory(:robo_recording, :script => script)
      @recording2 = Factory(:robo_recording, :script => script)
    end

    it "plays the next recording given the current one" do
      call_attempt.next_recording(@recording1).should == @recording2.twilio_xml(call_attempt)
    end

    it "plays the first recording next given no current recording" do
      call_attempt.next_recording.should == @recording1.twilio_xml(call_attempt)
    end

    it "hangs up given no next recording" do
      call_attempt.next_recording(@recording2).should == Twilio::Verb.new(&:hangup).response
    end

    it "hangs up when a recording has been responded to incorrectly 3 times" do
      Factory(:call_response, :robo_recording => @recording2, :call_attempt => call_attempt , :times_attempted => 3)
      call_attempt.next_recording(@recording2).should == Twilio::Verb.new(&:hangup).response
    end

    it "replays current recording has been responded to incorrectly < 3 times" do
      recording_response = Factory(:recording_response, :robo_recording => @recording2, :response => 'xyz', :keypad => 1)
      Factory(:call_response, :robo_recording => @recording2, :call_attempt => call_attempt , :times_attempted => 2)
      call_attempt.next_recording(@recording2).should == Twilio::Verb.new(&:hangup).response
    end
  end

  it "lists attempts between two dates" do
    too_old = Factory(:call_attempt).tap{|ca| ca.update_attribute(:created_at, 10.minutes.ago)}
    too_new = Factory(:call_attempt).tap{|ca| ca.update_attribute(:created_at, 10.minutes.from_now)}
    just_right = Factory(:call_attempt).tap{|ca| ca.update_attribute(:created_at, 8.minutes.ago)}
    another_just_right = Factory(:call_attempt).tap{|ca| ca.update_attribute(:created_at, 8.minutes.from_now)}
    CallAttempt.between(9.minutes.ago, 9.minutes.from_now)
  end

  describe 'status filtering' do
    let(:wanted_attempt) { Factory(:call_attempt, :status => 'foo') }
    let(:unwanted_attempt) { Factory(:call_attempt, :status => 'bar') }

    it "filters out attempts of certain statuses" do
      CallAttempt.without_status(['bar']).should == [wanted_attempt]
    end

    it "filters out attempts of everything but certain statuses" do
      CallAttempt.with_status(['foo']).should == [wanted_attempt]
    end
  end
end
