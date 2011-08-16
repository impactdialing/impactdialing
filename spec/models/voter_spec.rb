require "spec_helper"

describe Voter do
  include ActionController::UrlWriter

  it "can share the same number" do
    Factory(:voter, :Phone => '92345623434')
    Factory(:voter, :Phone => '92345623434')
    Voter.all.size.should == 2
  end

  it "should list existing entries in a campaign having the given phone number" do
    lambda {
      Factory(:voter, :Phone => '0123456789', :campaign_id => 99)
    }.should change {
      Voter.existing_phone_in_campaign('0123456789', 99).count
    }.by(1)
  end

  it "returns only active voters" do
    active_voter = Factory(:voter, :active => true)
    inactive_voter = Factory(:voter, :active => false)
    Voter.active.should == [active_voter]
  end


  it "conferences a caller" do
    voter = Factory(:voter)
    caller = Factory(:caller_session)

    voter.conference(caller).should == Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false' do |d|
        d.Conference "session#{caller.id}", :wait_url => "", :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
      end
    end.text
    caller.voter_in_progress.should == voter
  end

  describe "Dialing" do
    let(:campaign) { Factory(:campaign) }
    let(:voter) { Factory(:voter, :campaign => campaign) }

    it "is dialed" do
      call_attempt = Factory(:call_attempt)
      voter.should_receive(:new_call_attempt).and_return(call_attempt)
      callback_url = twilio_callback_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      fallback_url = twilio_report_error_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      callended_url = twilio_call_ended_url(:call_attempt_id => call_attempt, :host => Settings.host, :port => Settings.port)
      Twilio::Call.should_receive(:make).with(
          voter.campaign.caller_id,
          voter.Phone,
          callback_url,
          'FallbackUrl' => fallback_url,
          'StatusCallback' => callended_url,
          'Timeout' => '20',
          'IfMachine' => 'Hangup'
      ).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial
    end

    it "records a call attempt for a dialed voter" do
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "abcd"}}})
      lambda {
        voter.dial
      }.should change {
        voter.call_attempts.count
      }.by(1)

      call_attempt = voter.call_attempts.first
      call_attempt.campaign.should == campaign
      call_attempt.dialer_mode.should == "robo"
      call_attempt.status.should == CallAttempt::Status::INPROGRESS
      voter.last_call_attempt.should == call_attempt
    end

    it "updates the sid for a dialed voter" do
      sid = "xyzzyspoonshift1"
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => sid}}})
      voter.dial
      voter.call_attempts.last.sid.should == sid
    end

    it "records users to call back" do
      voter1 = Factory(:voter)
      Voter.to_callback.should == []
      voter2 = Factory(:voter, :call_back =>true)
      Voter.to_callback.should == [voter2]
    end
  end

  describe "predictive dialing" do
    let(:campaign) {Factory(:campaign, :robo => false, :predective_type => 'algorithm1')}
    let(:voter) { Factory(:voter, :campaign => campaign) }

    it "is dialed" do
      Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial_predictive
      call_attempt = voter.call_attempts.last
      call_attempt.sid.should == "sid"
      call_attempt.status.should == CallAttempt::Status::INPROGRESS
      voter.last_call_attempt.should == call_attempt
    end

    it "dials the voter and hangs up on answering machine when not using recordings" do
      campaign.use_recordings = false
      Twilio::Call.should_receive(:make).with( anything, anything, anything, {'IfMachine' => 'Hangup', 'Timeout' => 20} ).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial_predictive
    end

    it "dials the voter and continues on answering machine when using recordings" do
      campaign.use_recordings = true
      voter.campaign = campaign
      Twilio::Call.should_receive(:make).with(anything,anything,anything,{'IfMachine' => 'Continue', 'Timeout' => 20}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial_predictive
    end

    it "dials the voter with the campaigns answer detection timeout" do
      campaign.use_recordings = true
      campaign.answer_detection_timeout = "10"
      voter.campaign = campaign
      Twilio::Call.should_receive(:make).with(anything,anything,anything, {'IfMachine' => 'Continue', 'Timeout' => campaign.answer_detection_timeout}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial_predictive
    end

    it "dials with answer detection timeout defaults" do
      campaign.use_recordings = true
      voter.campaign = campaign
      Twilio::Call.should_receive(:make).with(anything,anything,anything, {'IfMachine' => 'Continue', 'Timeout' => 20}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
      voter.dial_predictive
    end

  end

  describe "to be dialed" do
    it "includes voters never called" do
      voter = Factory(:voter)
      Voter.to_be_dialed.should == [voter]
    end

    it "includes voters with a busy signal" do
      voter = Factory(:voter)
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::BUSY)
      Voter.to_be_dialed.should == [voter]
    end

    (CallAttempt::Status::ALL - [CallAttempt::Status::SUCCESS]).each do |status|
      it "includes voters with a status of #{status} " do
        voter = Factory(:voter)
        Factory(:call_attempt, :voter => voter, :status => status)
        Voter.to_be_dialed.should == [voter]
      end
    end

    it "excludes voters with a status of a successful call" do
      voter = Factory(:voter)
      Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::SUCCESS)
      Voter.to_be_dialed.should be_empty
    end
  end

  describe "voter attributes" do
    let(:voter) { Factory(:voter, :campaign => Factory(:campaign, :user=> Factory(:user)), :Phone => '384756923349') }

    it "populates original attributes" do
      voter.apply_attribute('Phone', '0123456789')
      voter.Phone.should == '0123456789'
    end

    it "populates custom attributes" do
      attribute, value = 'Custom', 'foo'
      voter.apply_attribute(attribute, value)
      field = CustomVoterField.find_by_name(attribute)
      field.should_not be_nil
      CustomVoterFieldValue.voter_fields(voter, field).first.value.should == value
    end

    it "returns value of original attributes" do
      attribute, value = 'Phone', '2947832874'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

    it "returns value of custom attributes" do
      attribute, value = 'Custom', 'abcde'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end
  end

  it "lists scheduled voters" do
    recent_voter = Factory(:voter, :scheduled_date => 2.minutes.ago, :status => CallAttempt::Status::SCHEDULED)
    really_old_voter = Factory(:voter, :scheduled_date => 2.hours.ago, :status => CallAttempt::Status::SCHEDULED)
    recent_but_unscheduled_voter = Factory(:voter, :scheduled_date => 1.minute.ago, :status => nil)
    Voter.scheduled.should == [recent_voter]
  end

  it "limits voters when listing them" do
    10.times { Factory(:voter) }
    Voter.limit(5).should have(5).voters
  end

  describe "voter attributes" do

    let(:voter) { Factory(:voter, :campaign => Factory(:campaign, :user=> Factory(:user)), :Phone => '384756923349') }

    it "populates original attributes" do
      voter.apply_attribute('Phone', '0123456789')
      voter.Phone.should == '0123456789'
    end

    it "populates custom attributes" do
      attribute, value = 'Custom', 'foo'
      voter.apply_attribute(attribute, value)
      field = CustomVoterField.find_by_name(attribute)
      field.should_not be_nil
      CustomVoterFieldValue.voter_fields(voter, field).first.value.should == value
    end

    it "returns value of original attributes" do
      attribute, value = 'Phone', '2947832874'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

    it "returns value of custom attributes" do
      attribute, value = 'Custom', 'abcde'
      voter.apply_attribute(attribute, value)
      voter.get_attribute(attribute).should == value
    end

  end
end
