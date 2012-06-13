require "spec_helper"
include Rails.application.routes.url_helpers

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
    call_attempt = Factory(:call_attempt, call_start:  Time.now, connecttime:  Time.now, call_end:  (Time.now + 150.seconds))
    Time.stub(:now).and_return(now + 150.seconds)
    call_attempt.duration_rounded_up.should == 3
  end

  it "rounds up the duration up to now if the call is still running" do
    now = Time.now
    call_attempt = Factory(:call_attempt, call_start:  now, connecttime:  Time.now, call_end:  nil)
    Time.stub(:now).and_return(now + 1.minute + 30.seconds)
    call_attempt.duration_rounded_up.should == 2
  end

  it "reports 0 minutes if the call hasn't even started" do
    call_attempt = Factory(:call_attempt, call_start: nil, connecttime:  Time.now, call_end:  nil)
    call_attempt.duration_rounded_up.should == 0
  end


  it "can be scheduled for later" do
    voter = Factory(:voter)
    call_attempt = Factory(:call_attempt, :voter => voter)
    scheduled_date = "10/10/2020 20:20"
    call_attempt.schedule_for_later(scheduled_date)
    call_attempt.reload.status.should == CallAttempt::Status::SCHEDULED
    call_attempt.scheduled_date.to_s.should eq("2020-10-10 20:20:00 UTC")
    call_attempt.voter.status.should == CallAttempt::Status::SCHEDULED
    call_attempt.voter.scheduled_date.to_s.should eq("2020-10-10 20:20:00 UTC")
    call_attempt.voter.call_back.should be_true
  end

  describe 'next recording' do
    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:campaign, :script => script) }
    let(:call_attempt) { Factory(:call_attempt, :campaign => campaign) }

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
      Factory(:call_response, :robo_recording => @recording2, :call_attempt => call_attempt, :times_attempted => 3)
      call_attempt.next_recording(@recording2).should == Twilio::Verb.new(&:hangup).response
    end

    it "replays current recording has been responded to incorrectly < 3 times" do
      recording_response = Factory(:recording_response, :robo_recording => @recording2, :response => 'xyz', :keypad => 1)
      Factory(:call_response, :robo_recording => @recording2, :call_attempt => call_attempt, :times_attempted => 2)
      call_attempt.next_recording(@recording2).should == Twilio::Verb.new(&:hangup).response
    end
  end




  it "lists attempts between two dates" do
    too_old = Factory(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = Factory(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = Factory(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = Factory(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    CallAttempt.between(9.minutes.ago, 9.minutes.from_now)
  end

  describe 'status filtering' do
    before(:each) do
      @wanted_attempt = Factory(:call_attempt, :status => 'foo')
      @unwanted_attempt = Factory(:call_attempt, :status => 'bar')
    end

    it "filters out attempts of certain statuses" do
      CallAttempt.without_status(['bar']).should == [@wanted_attempt]
    end

    it "filters out attempts of everything but certain statuses" do
      CallAttempt.with_status(['foo']).should == [@wanted_attempt]
    end
  end
  
  describe "call attempts between" do
    it "should return cal attempts between 2 dates" do
      Factory(:call_attempt, created_at: Time.now - 10.days)
      Factory(:call_attempt, created_at: Time.now - 1.month)
      call_attempts = CallAttempt.between(Time.now - 20.days, Time.now)
      call_attempts.length.should eq(1)
    end
  end

  describe "total call length" do
    it "should include the wrap up time if the call has been wrapped up" do
      call_attempt = Factory(:call_attempt, call_start:  Time.now - 3.minute, connecttime:  Time.now - 3.minute, wrapup_time:  Time.now)
      total_time = (call_attempt.wrapup_time - call_attempt.call_start).to_i
      call_attempt.duration_wrapped_up.should eq(total_time)
    end

    it "should return the duration from start to now if call has not been wrapped up " do
      call_attempt = Factory(:call_attempt, call_start: Time.now - 3.minute, connecttime:  Time.now - 3.minute)
      total_time = (Time.now - call_attempt.call_start).to_i
      call_attempt.duration_wrapped_up.should eq(total_time)
    end
  end
  
  describe "capture voter response, when call disconnected unexpectedly" do
    it "capture response as 'No response' for the questions, which are not answered" do
      script = Factory(:script)
      campaign = Factory(:campaign, :script => script)
      voter = Factory(:voter, :campaign => campaign)
      question = Factory(:question, :script => script)
      unanswered_question = Factory(:question, :script => script)
      possible_response = Factory(:possible_response, :question => question, :value => "ok")
      answer = Factory(:answer, :question => question, :campaign => campaign, :possible_response => possible_response, :voter => voter)
      call_attempt = Factory(:call_attempt, :connecttime => Time.now, :status => CallAttempt::Status::SUCCESS, :voter => voter, :campaign => campaign)
      call_attempt.capture_answer_as_no_response 
      question.possible_responses.count.should == 1
      question.answers.count.should == 1
      unanswered_question.possible_responses.count.should == 1
      unanswered_question.answers.count.should == 1
    end
    
    it "capture response as 'No response' for the robo_recordings, for which voter not responded" do
      script = Factory(:script)
      campaign = Factory(:campaign, :script => script)
      voter = Factory(:voter, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::SUCCESS, :campaign => campaign, :voter => voter)
      voter.update_attribute(:last_call_attempt, call_attempt)
      robo_recording = Factory(:robo_recording, :script => script)
      not_respond_robo_recording = Factory(:robo_recording, :script => script)
      recording_response = Factory(:recording_response, :robo_recording => robo_recording, :response => "ok")
      call_response = Factory(:call_response, :robo_recording => robo_recording, :campaign => campaign, :recording_response => recording_response, :call_attempt => call_attempt)
      
      call_attempt.capture_answer_as_no_response_for_robo 
      robo_recording.recording_responses.count.should == 1
      robo_recording.call_responses.count.should == 1
      not_respond_robo_recording.recording_responses.count.should == 1
      not_respond_robo_recording.call_responses.count.should == 1
    end
  end
  
  describe "wrapup call_attempts" do
    it "should wrapup all call_attempts that are not" do
      caller = Factory(:caller)
      another_caller = Factory(:caller)
      Factory(:call_attempt, caller_id: caller.id)
      Factory(:call_attempt, caller_id: another_caller)
      Factory(:call_attempt, caller_id: caller.id)
      Factory(:call_attempt, wrapup_time: Time.now-2.hours,caller_id: caller.id)
      CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length.should eq(2)
      CallAttempt.wrapup_calls(caller.id)
      CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length.should eq(0)
    end
  end
end
