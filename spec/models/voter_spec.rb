require "spec_helper"

describe Voter do
  include ActionController::UrlWriter

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


  describe "Dialing" do
    let(:campaign) { Factory(:campaign) }
    let(:voter) { Factory(:voter, :campaign => campaign) }

    it "is dialed" do
      call_attempt = Factory(:call_attempt)
      voter.should_receive(:new_call_attempt).and_return(call_attempt)
      callback_url = twilio_callback_url(:call_attempt_id => call_attempt, :host => HOST, :port => PORT)
      fallback_url = twilio_report_error_url(:call_attempt_id => call_attempt, :host => HOST, :port => PORT)
      callended_url = twilio_call_ended_url(:call_attempt_id => call_attempt, :host => HOST, :port => PORT)
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
end
