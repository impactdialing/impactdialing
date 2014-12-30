require "spec_helper"

describe CallAttempt, :type => :model do
  include Rails.application.routes.url_helpers

  describe '#update_recording!(delivered_manually=false)' do
    let(:recording){ create(:recording) }
    let(:campaign){ create(:power, {recording: recording}) }
    let(:voter){ create(:voter, {campaign: campaign}) }
    subject{ create(:call_attempt, {campaign: campaign, voter: voter}) }

    before do
      subject.update_recording!(true)
    end

    it 'sets self.recording_id to campaign.recording_id' do
      expect(subject.recording_id).to eq recording.id
    end

    it 'sets self.recording_delivered_manually to `delivered_manually` arg value' do
      expect(subject.recording_delivered_manually).to be_truthy
    end

    it 'save!s' do
      pre = subject
      expect(subject.reload).to eql pre
    end
  end

  it "lists all attempts for a campaign" do
    campaign = create(:campaign)
    attempt_of_our_campaign = create(:call_attempt, :campaign => campaign)
    attempt_of_another_campaign = create(:call_attempt, :campaign => create(:campaign))
    expect(CallAttempt.for_campaign(campaign).to_a).to match_array([attempt_of_our_campaign])
  end

  it "lists all attempts by status" do
    delivered_attempt = create(:call_attempt, :status => "Message delivered")
    successful_attempt = create(:call_attempt, :status => "Call completed with success.")
    expect(CallAttempt.for_status("Message delivered").to_a).to match_array([delivered_attempt])
  end

  it "rounds up the duration to the nearest minute" do
    now = Time.now
    call_attempt = create(:call_attempt, call_start:  Time.now, connecttime:  Time.now, call_end:  (Time.now + 150.seconds))
    allow(Time).to receive(:now).and_return(now + 150.seconds)
    expect(call_attempt.duration_rounded_up).to eq(3)
  end

  it "rounds up the duration up to now if the call is still running" do
    now = Time.now
    call_attempt = create(:call_attempt, call_start:  now, connecttime:  Time.now, call_end:  nil)
    allow(Time).to receive(:now).and_return(now + 1.minute + 30.seconds)
    expect(call_attempt.duration_rounded_up).to eq(2)
  end

  it "reports 0 minutes if the call hasn't even started" do
    call_attempt = create(:call_attempt, call_start: nil, connecttime:  Time.now, call_end:  nil)
    expect(call_attempt.duration_rounded_up).to eq(0)
  end

  it "should abandon call" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.abandoned(now)
    expect(call_attempt.status).to eq(CallAttempt::Status::ABANDONED)
    expect(call_attempt.connecttime).to eq(now)
    expect(call_attempt.call_end).to eq(now)
  end


  it "should end_answered_by_machine" do
    campaign = create(:power)
    voter = create(:voter, {campaign: campaign})
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    nowminus2 = now - 2.minutes
    call_attempt.end_answered_by_machine(nowminus2, now)
    expect(call_attempt.connecttime).to eq(nowminus2)
    expect(call_attempt.call_end).to eq(now)
    expect(call_attempt.wrapup_time).to eq(now)
  end

  it "should end_unanswered_call" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.end_unanswered_call("busy",now)
    expect(call_attempt.status).to eq("No answer busy signal")
    expect(call_attempt.call_end).to eq(now)
  end


  it "should disconnect call" do
     voter = create(:voter)
     call_attempt = create(:call_attempt, :voter => voter)
     caller = create(:caller)
     now = Time.now
     call_attempt.disconnect_call(now, 12, "url", caller.id)
     expect(call_attempt.status).to eq(CallAttempt::Status::SUCCESS)
     expect(call_attempt.call_end).to eq(now)
     expect(call_attempt.recording_duration).to eq(12)
     expect(call_attempt.recording_url).to eq("url")
     expect(call_attempt.caller_id).to eq(caller.id)
   end

  it "should wrapup call webui" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::TWILIO_CLIENT, voter.id)
    expect(call_attempt.wrapup_time).to eq(now)
    expect(call_attempt.voter_response_processed).to be_falsey
  end

  it "should wrapup call phones" do
    voter = create(:voter)
    caller = create(:caller, is_phones_only: true)
    call_attempt = create(:call_attempt, :voter => voter, :caller => caller)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::PHONE, voter.id)
    expect(call_attempt.wrapup_time).to eq(now)
    expect(call_attempt.voter_response_processed).to be_truthy
  end

  it "should wrapup call phones" do
    voter = create(:voter)
    caller = create(:caller, is_phones_only: false)
    call_attempt = create(:call_attempt, :voter => voter, caller: caller)
    now = Time.now
    call_attempt.wrapup_now(now, CallerSession::CallerType::PHONE, voter.id)
    expect(call_attempt.wrapup_time).to eq(now)
    expect(call_attempt.voter_response_processed).to be_falsey
  end

  it "should connect lead to caller" do
    voter = create(:voter)
    call_attempt = create(:call_attempt, :voter => voter)
    caller_session = create(:caller_session)
    expect(RedisOnHoldCaller).to receive(:longest_waiting_caller).and_return(caller_session.id)
    call_attempt.connect_caller_to_lead(DataCentre::Code::TWILIO)
    expect(caller_session.attempt_in_progress).to eq(call_attempt)
    expect(caller_session.voter_in_progress).to eq(voter)
  end



  it "lists attempts between two dates" do
    too_old = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = create(:call_attempt).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    CallAttempt.between(9.minutes.ago, 9.minutes.from_now)
  end

  describe 'status filtering' do
    before(:each) do
      @wanted_attempt = create(:call_attempt, :status => 'foo')
      @unwanted_attempt = create(:call_attempt, :status => 'bar')
    end

    it "filters out attempts of certain statuses" do
      expect(CallAttempt.without_status(['bar'])).to eq([@wanted_attempt])
    end

    it "filters out attempts of everything but certain statuses" do
      expect(CallAttempt.with_status(['foo'])).to eq([@wanted_attempt])
    end
  end

  describe "call attempts between" do
    it "should return cal attempts between 2 dates" do
      create(:call_attempt, created_at: Time.now - 10.days)
      create(:call_attempt, created_at: Time.now - 1.month)
      call_attempts = CallAttempt.between(Time.now - 20.days, Time.now)
      expect(call_attempts.length).to eq(1)
    end
  end

  describe "total call length" do
    it "should include the wrap up time if the call has been wrapped up" do
      call_attempt = create(:call_attempt, call_start:  Time.now - 3.minute, connecttime:  Time.now - 3.minute, wrapup_time:  Time.now)
      total_time = (call_attempt.wrapup_time - call_attempt.call_start).to_i
      expect(call_attempt.duration_wrapped_up).to eq(total_time)
    end

    it "should return the duration from start to now if call has not been wrapped up " do
      call_attempt = create(:call_attempt, call_start: Time.now - 3.minute, connecttime:  Time.now - 3.minute)
      total_time = (Time.now - call_attempt.call_start).to_i
      expect(call_attempt.duration_wrapped_up).to eq(total_time)
    end
  end


  describe "wrapup call_attempts" do
    it "should wrapup all call_attempts that are not" do
      caller = create(:caller)
      another_caller = create(:caller)
      create(:call_attempt, caller_id: caller.id)
      create(:call_attempt, caller_id: another_caller.id)
      create(:call_attempt, caller_id: caller.id)
      create(:call_attempt, wrapup_time: Time.now-2.hours,caller_id: caller.id)
      expect(CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length).to eq(2)
      CallAttempt.wrapup_calls(caller.id)
      expect(CallAttempt.not_wrapped_up.find_all_by_caller_id(caller.id).length).to eq(0)
    end
  end
end

# ## Schema Information
#
# Table name: `call_attempts`
#
# ### Columns
#
# Name                                | Type               | Attributes
# ----------------------------------- | ------------------ | ---------------------------
# **`id`**                            | `integer`          | `not null, primary key`
# **`voter_id`**                      | `integer`          |
# **`sid`**                           | `string(255)`      |
# **`status`**                        | `string(255)`      |
# **`campaign_id`**                   | `integer`          |
# **`call_start`**                    | `datetime`         |
# **`call_end`**                      | `datetime`         |
# **`caller_id`**                     | `integer`          |
# **`connecttime`**                   | `datetime`         |
# **`caller_session_id`**             | `integer`          |
# **`created_at`**                    | `datetime`         |
# **`updated_at`**                    | `datetime`         |
# **`result`**                        | `string(255)`      |
# **`result_digit`**                  | `string(255)`      |
# **`tCallSegmentSid`**               | `string(255)`      |
# **`tAccountSid`**                   | `string(255)`      |
# **`tCalled`**                       | `string(255)`      |
# **`tCaller`**                       | `string(255)`      |
# **`tPhoneNumberSid`**               | `string(255)`      |
# **`tStatus`**                       | `string(255)`      |
# **`tDuration`**                     | `integer`          |
# **`tFlags`**                        | `integer`          |
# **`tStartTime`**                    | `datetime`         |
# **`tEndTime`**                      | `datetime`         |
# **`tPrice`**                        | `float`            |
# **`dialer_mode`**                   | `string(255)`      |
# **`scheduled_date`**                | `datetime`         |
# **`recording_url`**                 | `string(255)`      |
# **`recording_duration`**            | `integer`          |
# **`wrapup_time`**                   | `datetime`         |
# **`call_id`**                       | `integer`          |
# **`voter_response_processed`**      | `boolean`          | `default(FALSE)`
# **`debited`**                       | `boolean`          | `default(FALSE)`
# **`recording_id`**                  | `integer`          |
# **`recording_delivered_manually`**  | `boolean`          | `default(FALSE)`
# **`household_id`**                  | `integer`          |
#
# ### Indexes
#
# * `index_call_attempts_debit`:
#     * **`debited`**
#     * **`status`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
# * `index_call_attempts_on_call_end`:
#     * **`call_end`**
# * `index_call_attempts_on_call_id`:
#     * **`call_id`**
# * `index_call_attempts_on_caller_id_and_wrapup_time`:
#     * **`caller_id`**
#     * **`wrapup_time`**
# * `index_call_attempts_on_caller_session_id`:
#     * **`caller_session_id`**
# * `index_call_attempts_on_campaign_created_id`:
#     * **`campaign_id`**
#     * **`created_at`**
#     * **`id`**
# * `index_call_attempts_on_campaign_id`:
#     * **`campaign_id`**
# * `index_call_attempts_on_campaign_id_and_call_end`:
#     * **`campaign_id`**
#     * **`call_end`**
# * `index_call_attempts_on_campaign_id_and_wrapup_time`:
#     * **`campaign_id`**
#     * **`wrapup_time`**
# * `index_call_attempts_on_campaign_id_created_at_status`:
#     * **`campaign_id`**
#     * **`created_at`**
#     * **`status`**
# * `index_call_attempts_on_created_at`:
#     * **`created_at`**
# * `index_call_attempts_on_household_id`:
#     * **`household_id`**
# * `index_call_attempts_on_voter_id`:
#     * **`voter_id`**
# * `index_call_attempts_on_voter_response_processed_and_status`:
#     * **`voter_response_processed`**
#     * **`status`**
# * `index_sync_calls`:
#     * **`status`**
#     * **`tPrice`**
#     * **`tStatus`**
#     * **`sid`**
#
