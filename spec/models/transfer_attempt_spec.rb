require "spec_helper"

describe TransferAttempt, :type => :model do

  describe "conference" do
    it "should return the conference twiml" do
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      transfer = create(:transfer, phone_number: "1234567890")
      transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      expect(transfer_attempt.conference).not_to be_nil
    end
  end

  describe "fail" do
    it "should return correct twiml" do
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      transfer = create(:transfer, phone_number: "1234567890")
      transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      expect(transfer_attempt.fail).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    end
  end

  describe "hangup" do
    it "should return correct twiml" do
      caller_session = create(:caller_session)
      call_attempt = create(:call_attempt)
      transfer = create(:transfer, phone_number: "1234567890")
      transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
      expect(transfer_attempt.hangup).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
  end

  describe "attempts within" do
    it "should return attempts within a date range" do
      caller_session = create(:caller_session, sid: "SID")
      transfer = create(:transfer, phone_number: "1234567890", label: "A")

      campaign = create(:campaign)
      now = Time.now
      transfer_attempt1 = create(:transfer_attempt, caller_session: caller_session, created_at: (now - 2.days), campaign_id: campaign.id, transfer_id: transfer.id)
      transfer_attempt2 = create(:transfer_attempt, caller_session: caller_session, created_at: (now + 1.days), campaign_id: campaign.id, transfer_id: transfer.id)
      transfer_attempt3 = create(:transfer_attempt, caller_session: caller_session, created_at:  (now + 10.hours), campaign_id: campaign.id, transfer_id: transfer.id)
      expect(TransferAttempt.within(now, now + 1.day, campaign.id)).to eq([transfer_attempt2, transfer_attempt3])
    end
  end

  describe "aggregate" do
    it "should aggregrate call attempts" do
      caller_session = create(:caller_session, sid: "SID")
      transfer1 = create(:transfer, phone_number: "1234567890", label: "A")
      transfer2 = create(:transfer, phone_number: "1234567890", label: "B")
      transfer3 = create(:transfer, phone_number: "1234567890", label: "C")
      campaign = create(:campaign)
      transfer_attempt1 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
      transfer_attempt2 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer2.id)
      transfer_attempt3 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
      transfer_attempt4 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer3.id)
      transfer_attempt5 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer2.id)
      transfer_attempt6 = create(:transfer_attempt, caller_session: caller_session, campaign_id: campaign.id, transfer_id: transfer1.id)
      result  = TransferAttempt.aggregate(campaign.transfer_attempts)
      expect(result[transfer1.id][:label]).to eq("A")
      expect(result[transfer1.id][:number]).to eq(3)
      expect(result[transfer1.id][:percentage]).to eq(50)
      expect(result[transfer2.id][:label]).to eq("B")
      expect(result[transfer2.id][:number]).to eq(2)
      expect(result[transfer2.id][:percentage]).to eq(33)
      expect(result[transfer3.id][:label]).to eq("C")
      expect(result[transfer3.id][:number]).to eq(1)
      expect(result[transfer3.id][:percentage]).to eq(16)

    end
  end
end

# ## Schema Information
#
# Table name: `transfer_attempts`
#
# ### Columns
#
# Name                     | Type               | Attributes
# ------------------------ | ------------------ | ---------------------------
# **`id`**                 | `integer`          | `not null, primary key`
# **`transfer_id`**        | `integer`          |
# **`caller_session_id`**  | `integer`          |
# **`call_attempt_id`**    | `integer`          |
# **`script_id`**          | `integer`          |
# **`campaign_id`**        | `integer`          |
# **`call_start`**         | `datetime`         |
# **`call_end`**           | `datetime`         |
# **`status`**             | `string(255)`      |
# **`connecttime`**        | `datetime`         |
# **`sid`**                | `string(255)`      |
# **`session_key`**        | `string(255)`      |
# **`created_at`**         | `datetime`         |
# **`updated_at`**         | `datetime`         |
# **`transfer_type`**      | `string(255)`      |
# **`tPrice`**             | `float`            |
# **`tStatus`**            | `string(255)`      |
# **`tCallSegmentSid`**    | `string(255)`      |
# **`tAccountSid`**        | `string(255)`      |
# **`tCalled`**            | `string(255)`      |
# **`tCaller`**            | `string(255)`      |
# **`tPhoneNumberSid`**    | `string(255)`      |
# **`tStartTime`**         | `datetime`         |
# **`tEndTime`**           | `datetime`         |
# **`tDuration`**          | `integer`          |
# **`tFlags`**             | `integer`          |
# **`debited`**            | `boolean`          | `default(FALSE)`
#
# ### Indexes
#
# * `index_transfer_attempts_debit`:
#     * **`debited`**
#     * **`status`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
#
