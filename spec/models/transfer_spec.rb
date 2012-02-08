require "spec_helper"

describe Transfer do
  
  describe "dial" do
    it "should make a call and update attempt with call sid" do
      voter = Factory(:voter, Phone: "1234567890")
      transfer = Factory(:transfer, phone_number: "9878987654")
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      voter = Factory(:voter)
      Twilio::Call.should_receive(:make).with(voter.Phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.sid.should eq('sid')
    end
    
    it "should create a transfer attempt" do
      voter = Factory(:voter, Phone: "1234567890")
      transfer = Factory(:transfer, phone_number: "9878987654")
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      voter = Factory(:voter)
      Twilio::Call.should_receive(:make).with(voter.Phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.status.should eq(CallAttempt::Status::RINGING)
    end
    
    it "should create a transfer attempt with status failed if cannot make call" do
      voter = Factory(:voter, Phone: "1234567890")
      transfer = Factory(:transfer, phone_number: "98789876")
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      voter = Factory(:voter)
      Twilio::Call.should_receive(:make).with(voter.Phone, transfer.phone_number, anything, anything).and_return("TwilioResponse"=> {"RestException" => {}})
      transfer.dial(caller_session, call_attempt, voter, Transfer::Type::WARM)
      transfer.transfer_attempts.first.status.should eq(CallAttempt::Status::FAILED)
    end    
    
  end
end
