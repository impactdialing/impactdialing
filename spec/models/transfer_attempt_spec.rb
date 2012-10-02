require "spec_helper"

describe TransferAttempt do

  describe "conference" do
    it "should return the conference twiml" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt)
      transfer = Factory(:transfer, phone_number: "1234567890")
      transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      transfer_attempt.conference.should_not be_nil
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
      Twilio::Call.should_receive(:redirect).with(call_attempt.sid, "https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/callee")
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
        Twilio::Call.should_receive(:redirect).with(caller_session.sid, "https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/caller?caller_session=#{caller_session.id}")
        transfer_attempt.redirect_caller
      end
    end

    describe "attempts within" do
      it "should return attempts within a date range" do
        caller_session = Factory(:caller_session, sid: "SID")
        transfer = Factory(:transfer, phone_number: "1234567890", label: "A")

        campaign = Factory(:campaign)
        now = Time.now
        transfer_attempt1 = Factory(:transfer_attempt, caller_session: caller_session, created_at: (now - 2.days), campaign_id: campaign.id, transfer_id: transfer.id)
        transfer_attempt2 = Factory(:transfer_attempt, caller_session: caller_session, created_at: (now + 1.days), campaign_id: campaign.id, transfer_id: transfer.id)
        transfer_attempt3 = Factory(:transfer_attempt, caller_session: caller_session, created_at:  (now + 10.hours), campaign_id: campaign.id, transfer_id: transfer.id)
        TransferAttempt.within(now, now + 1.day, campaign.id).should eq([transfer_attempt2, transfer_attempt3])
      end
    end

    describe "aggregate" do
      it "should aggregrate call attempts" do
        caller_session = Factory(:caller_session, sid: "SID")
        transfer1 = Factory(:transfer, phone_number: "1234567890", label: "A")
        transfer2 = Factory(:transfer, phone_number: "1234567890", label: "B")
        transfer3 = Factory(:transfer, phone_number: "1234567890", label: "C")
        campaign = Factory(:campaign)
        transfer_attempt1 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
        transfer_attempt2 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer2.id)
        transfer_attempt3 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
        transfer_attempt4 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer3.id)
        transfer_attempt5 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer2.id)
        transfer_attempt6 = Factory(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
        result  = TransferAttempt.aggregate(campaign.transfer_attempts)
        result[transfer1.id][:label].should eq("A")
        result[transfer1.id][:number].should eq(3)
        result[transfer1.id][:percentage].should eq(50)
        result[transfer2.id][:label].should eq("B")
        result[transfer2.id][:number].should eq(2)
        result[transfer2.id][:percentage].should eq(33)
        result[transfer3.id][:label].should eq("C")
        result[transfer3.id][:number].should eq(1)
        result[transfer3.id][:percentage].should eq(16)

      end
    end

end
