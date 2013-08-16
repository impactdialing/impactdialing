require "spec_helper"

describe Transfer do

  describe "phone number" do
    it "should sanitize the phone number" do
      transfer = create(:transfer, phone_number: "(203) 643-0521")
      transfer.phone_number.should eq('2036430521')
    end

    it "should throw validatio error if phone number is not valid" do
      transfer = build(:transfer, phone_number: "9090909")
      transfer.should_not be_valid
    end

  end

  describe "dial" do
    it "should make a call and update attempt with call sid" do
      voter = create(:voter, phone: "1234567890")
      transfer = create(:transfer, phone_number: "9878987654")
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      voter = create(:voter)
      Twilio::Call.should_receive(:make).with(voter.phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.sid.should eq('sid')
    end

    it "should create a transfer attempt" do
      voter = create(:voter, phone: "1234567890")
      transfer = create(:transfer, phone_number: "9878987654")
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      voter = create(:voter)
      Twilio::Call.should_receive(:make).with(voter.phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.status.should eq(CallAttempt::Status::RINGING)
    end

    it "should create a transfer attempt with status failed if cannot make call" do
      voter = create(:voter, phone: "1234567890")
      transfer = create(:transfer, phone_number: "9923700678")
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      voter = create(:voter)
      Twilio::Call.should_receive(:make).with(voter.phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"RestException" => {}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.status.should eq(CallAttempt::Status::FAILED)
    end

  end
end
