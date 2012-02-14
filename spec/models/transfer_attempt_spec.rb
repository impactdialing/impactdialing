require "spec_helper"

describe TransferAttempt do
  
  describe "conference" do
    it "should return the conference twiml" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      transfer = Factory(:transfer, phone_number: "1234567890")
      transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      transfer_attempt.conference.should_not be_nil
      transfer_attempt.call_start.should_not be_nil
    end
  end
  
  describe "fail" do
    it "should return correct twiml" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      transfer = Factory(:transfer, phone_number: "1234567890")
      transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      transfer_attempt.fail.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    end
  end
  
  describe "hangup" do
    it "should return correct twiml" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      transfer = Factory(:transfer, phone_number: "1234567890")
      transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      transfer_attempt.hangup.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")      
    end
  end
  
  describe "redirect callee" do
    it "should redirect the callee" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt, sid: "SID")
      transfer = Factory(:transfer, phone_number: "1234567890")
      transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)      
      Twilio.should_receive(:connect)
      Twilio::Call.should_receive(:redirect).with(call_attempt.sid, "https://3ngz.localtunnel.com:3000/transfer/callee")
      transfer_attempt.redirect_callee
    end
  end
    
    describe "redirect caller" do
      it "should redirect the caller" do
        caller_session = Factory(:caller_session, sid: "SID")
        call_attempt = Factory(:call_attempt)
        transfer = Factory(:transfer, phone_number: "1234567890")
        transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)      
        Twilio.should_receive(:connect)
        Twilio::Call.should_receive(:redirect).with(caller_session.sid, "https://3ngz.localtunnel.com:3000/transfer/caller?caller_session=#{caller_session.id}")
        transfer_attempt.redirect_caller
      end
    
    end
  
end
