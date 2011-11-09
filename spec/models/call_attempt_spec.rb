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

  it "records a failed attempt" do
    campaign = Factory(:campaign, :use_web_ui => false)
    Factory(:voter, :campaign => campaign, :call_back => false)
    caller_session = Factory(:caller_session, :campaign => campaign)
    call_attempt = Factory(:call_attempt, :voter => Factory(:voter, :status => Voter::Status::NOTCALLED), :caller_session => caller_session, :campaign => campaign)
    call_attempt.fail
    call_attempt.voter.reload.call_back.should be_true
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

  describe "voter connected" do
    it "makes an attempt wait" do
      call_attempt = Factory(:call_attempt)
      call_attempt.wait(2).should == Twilio::TwiML::Response.new do |r|
        r.Pause :length => 2
        r.Redirect "#{connect_call_attempt_path(call_attempt)}"
      end.text
    end

    it "conferences a call_attempt to a caller_session" do
      session = Factory(:caller_session, :caller => Factory(:caller), :session_key => "example_key")
      voter = Factory(:voter)
      call_attempt = Factory(:call_attempt, :voter => voter)
      call_attempt.conference(session).should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host) do |d|
          d.Conference session.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
      session.voter_in_progress.should == voter
    end

    it "connects a successful call attempt to a caller_session when available" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.connect_to_caller.should == call_attempt.conference(caller_session)
      call_attempt.caller.should == caller_session.caller
      caller_session.attempt_in_progress.should == call_attempt
    end

    it "connects a successful call attempt to a specified caller_session " do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.connect_to_caller(caller_session).should == call_attempt.conference(caller_session)
      call_attempt.caller.should == caller_session.caller
    end

    it "hangs up a successful call attempt when no one is on call" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      call_attempt.connect_to_caller.should == call_attempt.hangup
    end

    it "plays a recorded message to the voters answering machine and hangs up" do
      campaign = Factory(:campaign, :use_recordings => true, :recording => Factory(:recording, :file_file_name => 'abc.mp3'))
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

    it "disconnects the voter from the caller" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session)
      time_now = Time.now
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
      voter = Factory(:voter)
      attempt = Factory(:call_attempt, :voter => voter)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign)
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("voter_connected", anything)
      attempt.voter.stub(:conference)
      attempt.conference(session)
    end

    it "pushes voter details" do
      voter = Factory(:voter)
      attempt = Factory(:call_attempt, :voter => voter)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => Factory(:campaign), :voter_in_progress => voter)
      session.should_receive(:publish).with("voter_connected", {:attempt_id => attempt.id, :voter => voter.info})
      attempt.voter.stub(:conference)
      attempt.conference(session)
    end

    it "pushes 'voter_disconnected' event when a call_attempt ends" do
      voter = Factory(:voter, :status => CallAttempt::Status::SUCCESS)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => Factory(:campaign, :use_web_ui => true))
      attempt = Factory(:call_attempt, :voter => voter, :caller_session => session)
      channel = mock
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_disconnected", {:attempt_id => attempt.id, :voter => attempt.voter.info})
      attempt.disconnect
    end

    it "pushes 'voter_push' when a failed call attempt ends" do
      campaign = Factory(:campaign, :use_web_ui => true)
      Factory(:voter, :status => Voter::Status::NOTCALLED, :call_back => false, :campaign => campaign)
      session = Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign)
      attempt = Factory(:call_attempt, :voter => Factory(:voter, :status => CallAttempt::Status::INPROGRESS), :caller_session => session, :campaign => campaign)
      channel = mock
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", campaign.all_voters.to_be_dialed.first.info.merge(:dialer => campaign.predictive_type))
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
end
