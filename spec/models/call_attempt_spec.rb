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
    call_attempt = Factory(:call_attempt, :call_start => Time.now, :call_end => (Time.now + 150.seconds))
    Time.stub(:now).and_return(now + 150.seconds)
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

  it "records a failed attempt" do
    campaign = Factory(:campaign, :use_web_ui => false)
    Factory(:voter, :campaign => campaign, :call_back => false)
    caller_session = Factory(:caller_session, :campaign => campaign, :session_key => "sample")
    call_attempt = Factory(:call_attempt, :voter => Factory(:voter, :status => Voter::Status::NOTCALLED), :caller_session => caller_session, :campaign => campaign)
    campaign.stub!(:time_period_exceed?).and_return(false)
    caller_session.stub!(:caller_reassigned_to_another_campaign?).and_return(false)
    call_attempt.fail
  end

  it "can be scheduled for later" do
    voter = Factory(:voter)
    call_attempt = Factory(:call_attempt, :voter => voter)
    scheduled_date = 2.hours.from_now
    call_attempt.schedule_for_later(scheduled_date)
    call_attempt.reload.status.should == CallAttempt::Status::SCHEDULED
    call_attempt.scheduled_date.to_s.should == scheduled_date.to_s
    call_attempt.voter.status.should == CallAttempt::Status::SCHEDULED
    call_attempt.voter.scheduled_date.to_s.should == scheduled_date.to_s
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

  describe "voicemails" do
    let(:voicemail){Factory(:robo_recording)}
    let(:campaign){ Factory(:campaign, :robo => true, :voicemail_script => Factory(:script, :robo => true, :for_voicemail => true, :robo_recordings => [voicemail]))}

    it "are left on a call_attempt" do
      call_attempt = Factory(:call_attempt, :campaign => campaign, :voter => Factory(:voter))
      call_attempt.leave_voicemail.should == voicemail.play_message(call_attempt)
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.reload.status.should == CallAttempt::Status::VOICEMAIL
    end
  end

  describe "voter connected" do
    it "makes an attempt wait" do
      call_attempt = Factory(:call_attempt)
      call_attempt.wait(2).should == Twilio::TwiML::Response.new do |r|
        r.Pause :length => 2
        r.Redirect "#{connect_call_attempt_path(call_attempt)}"
      end.text
    end

    it "conferences a call_attempt to a caller_session" do
      campaign = Factory(:campaign)
      session = Factory(:caller_session, :caller => Factory(:caller), :session_key => "example_key")
      voter = Factory(:voter, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      Moderator.stub!(:publish_event).with(call_attempt.campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, :caller_id => session.caller.id})
      call_attempt.conference(session).should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host), :record=>call_attempt.campaign.account.record_calls do |d|
          d.Conference session.session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
      call_attempt.reload.call_start.should_not be_nil
      session.voter_in_progress.should == voter
    end

    it "connects a successful call attempt to a caller_session when available" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.update_attributes(caller_session: caller_session)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => caller_session.campaign.id, 
        :caller_id => caller_session.caller.id})
      call_attempt.connect_to_caller.should == call_attempt.conference(caller_session)
      call_attempt.caller.should == caller_session.caller
      caller_session.attempt_in_progress.should == call_attempt
      call_attempt.status.should == CallAttempt::Status::INPROGRESS
    end

    it "connects a successful call attempt to a specified caller_session " do
      campaign = Factory(:campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      voter = Factory(:voter, :campaign => campaign, caller_session: caller_session)
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))

      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => caller_session.campaign.id,
        :caller_id => caller_session.caller.id})
      call_attempt.connect_to_caller.should == call_attempt.conference(caller_session)
      call_attempt.caller.should == caller_session.caller
    end

    it "connects a call to any available caller" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.update_attributes(caller_session: caller_session)
      Moderator.stub!(:publish_event).with(call_attempt.campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => call_attempt.campaign.id,
        :caller_id => caller_session.caller.id})
      call_attempt.connect_to_caller
      call_attempt.reload.caller_session.should == caller_session
      caller_session.attempt_in_progress.should == call_attempt
    end

    it "hangs up a successful call attempt when no one is on call" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      attempt_response = call_attempt.connect_to_caller
      attempt_response.should == call_attempt.hangup
      call_attempt.status.should eq(CallAttempt::Status::ABANDONED)
    end

    it "plays a recorded message to the voters answering machine and hangs up" do
      account = Factory(:account)
      campaign = Factory(:campaign, :use_recordings => true, :account => account, :recording => Factory(:recording, :file_file_name => 'abc.mp3', :account => account))
      voter = Factory(:voter, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.play_recorded_message.should == Twilio::TwiML::Response.new do |r|
        r.Play campaign.recording.file.url
        r.Hangup
      end.text
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.call_end.should_not be_nil
    end

    it "hangs up to answering machines when the campaign does not use recordings" do
      account = Factory(:account)
      campaign = Factory(:campaign, :use_recordings => false, :account => account, :recording => Factory(:recording, :file_file_name => 'abc.mp3', :account => account))
      voter = Factory(:voter, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.play_recorded_message.should == Twilio::Verb.hangup
      call_attempt.reload.status.should == CallAttempt::Status::HANGUP
      call_attempt.voter.status.should == CallAttempt::Status::HANGUP
      call_attempt.call_end.should_not be_nil
    end

    it "disconnects the voter from the caller" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session)
      time_now = Time.now
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_disconnected', {:caller_session_id => caller_session.id ,:campaign_id => call_attempt.campaign.id,
        :caller_id => caller_session.caller.id, :voters_remaining => 0})
      Time.stub(:now).and_return(time_now)
      call_attempt.disconnect
      call_attempt.reload.status.should == CallAttempt::Status::SUCCESS
      call_attempt.reload.call_end.should_not be_nil
      call_attempt.voter.status.should == call_attempt.status
    end

    it "disconnects a call_attempt from a call given an sid" do
      pending
    end
  end

  describe "Pusher" do

    it "notifies a call attempt being conferenced to a session" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign)
      channel = mock
      Moderator.stub!(:publish_event).with(session.campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, :caller_id => session.caller.id})
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger_async).with("voter_connected", anything)
      attempt.voter.stub(:conference)
      attempt.conference(session)
    end

    it "pushes voter details" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      
      attempt = Factory(:call_attempt, :campaign => campaign, :voter => voter)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign, :voter_in_progress => voter)
      Moderator.stub!(:publish_event).with(session.campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, 
        :caller_id => session.caller.id})
      session.should_receive(:publish).with("voter_connected", {:attempt_id => attempt.id, :voter => attempt.voter.info})
      attempt.voter.stub(:conference)
      attempt.conference(session)
    end

    it "pushes 'voter_disconnected' event when a call_attempt ends" do
      campaign = Factory(:campaign, :use_web_ui => true)
      voter = Factory(:voter, :campaign => campaign, :status => CallAttempt::Status::SUCCESS)
      
      caller_session = Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign)
      attempt = Factory(:call_attempt, :voter => voter, :caller_session => caller_session, :campaign => campaign)
      channel = mock
      Moderator.should_receive(:publish_event).with(attempt.campaign, 'voter_disconnected', {:caller_session_id => caller_session.id, :campaign_id => attempt.campaign.id,
         :caller_id => caller_session.caller.id, :voters_remaining=>0})
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger_async).with("voter_disconnected", {:attempt_id => attempt.id, :voter => attempt.voter.info})
      attempt.disconnect
    end

    it "pushes 'voter_push' when a failed call attempt ends" do
      campaign = Factory(:campaign, :use_web_ui => true)
      Factory(:voter, :status => Voter::Status::NOTCALLED, :call_back => false, :campaign => campaign)
      session = Factory(:caller_session, :caller => Factory(:caller, :campaign => campaign), :campaign => campaign, :session_key => "sample")
      attempt = Factory(:call_attempt, :voter => Factory(:voter, :status => CallAttempt::Status::INPROGRESS), :caller_session => session, :campaign => campaign)
      campaign.stub!(:time_period_exceed?).and_return(false)
      channel = mock
      info = campaign.all_voters.to_be_dialed.first.info
      info[:fields]['status'] = CallAttempt::Status::READY
      Pusher.should_receive(:[]).twice.with(anything).and_return(channel)
      channel.should_receive(:trigger_async).with("voter_push", info.merge(:dialer => campaign.predictive_type))
      channel.should_receive(:trigger_async).with("conference_started", {:dialer => campaign.predictive_type})
      attempt.fail
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
      call_attempt = Factory(:call_attempt, :call_start => Time.now - 3.minute, :wrapup_time => Time.now)
      total_time = (call_attempt.wrapup_time - call_attempt.call_start).to_i
      call_attempt.duration_wrapped_up.should eq(total_time)
    end

    it "should return the duration from start to now if call has not been wrapped up " do
      call_attempt = Factory(:call_attempt, :call_start => Time.now - 3.minute)
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
