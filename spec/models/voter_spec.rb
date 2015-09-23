require 'rails_helper'

describe Voter, :type => :model do
  include Rails.application.routes.url_helpers

  describe 'Voter::Status' do
    it 'defines NOTCALLED as "not called"' do
      expect(Voter::Status::NOTCALLED).to eq 'not called'
    end
    it 'defines RETRY as "retry"' do
      expect(Voter::Status::RETRY).to eq 'retry'
    end
    it 'defines SKIPPED as "skipped"' do
      expect(Voter::Status::SKIPPED).to eq 'skipped'
    end
  end

  describe 'cache?' do
    let(:voter){ create(:voter) }
    let(:household){ voter.household }
    let(:possible_legacy_statuses) do
      [
        Voter::Status::NOTCALLED, Voter::Status::RETRY,
        CallAttempt::Status::FAILED, CallAttempt::Status::SUCCESS,
        CallAttempt::Status::ABANDONED, CallAttempt::Status::INPROGRESS,
        CallAttempt::Status::NOANSWER, CallAttempt::Status::BUSY,
        CallAttempt::Status::HANGUP, CallAttempt::Status::READY,
        CallAttempt::Status::CANCELLED, CallAttempt::Status::RINGING
      ]
    end
    context 'household.cache? is false' do
      before do
        allow(household).to receive(:cache?){ false }
        allow(voter).to receive(:household){ household }
      end
      it 'returns false regardless of voter.status' do
        possible_legacy_statuses.each do |status|
          voter.status = status
          expect(voter.cache?).to(be_falsey, "Expected Voter with status of #{status} to not be cacheable")
        end
      end
    end
    context 'household.cache? is true' do
      before do
        allow(household).to receive(:cache?){ true }
        allow(voter).to receive(:household){ household }
      end
      it 'returns true when voter status is not CallAttempt::Status::SUCCESS or CallAttempt::Status::FAILED' do
        statuses_for_true = possible_legacy_statuses - [CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED]
        statuses_for_true.each do |status|
          voter.status = status
          expect(voter.cache?).to(be_truthy, "Expected Voter with status of #{status} to be cacheable")
        end
      end
      it 'returns false when voter status is CallAttempt::Status::SUCCESS or CallAttempt::Status::FAILED' do
        statuses_for_false = [CallAttempt::Status::SUCCESS, CallAttempt::Status::FAILED]
        statuses_for_false.each do |status|
          voter.status = status
          expect(voter.cache?).to(be_falsey, "Expected Voter with status of #{status} to not be cacheable")
        end
      end
    end
  end

  describe '#complete?' do
    let(:voter){ build(:voter) }
    it 'returns true if voter status == CallAttempt::Status::SUCCESS' do
      voter.status = CallAttempt::Status::SUCCESS
      expect(voter.complete?).to be_truthy
    end

    it 'returns true if voter status == CallAttempt::Status::FAILED' do
      voter.status = CallAttempt::Status::FAILED
      expect(voter.complete?).to be_truthy
    end

    it 'returns false when voicemail was delivered to house & campaign set to call back after voicemail delivery' do
      allow(voter).to receive(:call_back_regardless_of_status?){ true }
      expect(voter.complete?).to be_falsey
    end
  end

  describe '#do_not_call_back?' do
    let(:voter){ build(:voter) }
    it 'returns false when status == NOTCALLED' do
      expect(voter.status).to eq Voter::Status::NOTCALLED
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns false when call_back == true' do
      voter.call_back = true
      voter.status    = CallAttempt::Status::SUCCESS
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns false when status == RETRY' do
      voter.status = Voter::Status::RETRY
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns false when voicemail delivered to house & campaign set to call back after voicemail delivery' do
      allow(voter).to receive(:call_back_regardless_of_status?){ true }
      expect(voter.do_not_call_back?).to be_falsey
    end

    it 'returns true when status != NOTCALLED and status != RETRY and call_back == false' do
      voter.status = CallAttempt::Status::SUCCESS
      expect(voter.do_not_call_back?).to be_truthy
    end
  end

  describe '#dispositioned(call_attempt)' do
    let(:caller) do
      create(:caller)
    end
    let(:caller_session) do
      create(:webui_caller_session, campaign: caller.campaign, caller: caller)
    end
    let(:voter) do
      create(:voter, caller_session: caller_session, campaign: caller.campaign)
    end
    let(:call_attempt) do
      create(:call_attempt, {
        status: CallAttempt::Status::SUCCESS,
        caller: create(:caller, campaign: voter.campaign),
        campaign: voter.campaign
      })
    end

    it 'sets status to CallAttempt::Status::SUCCESS' do
      call_attempt.status = nil
      voter.dispositioned(call_attempt)
      expect(voter.status).to eq CallAttempt::Status::SUCCESS
    end

    it 'tries to set caller_id to call_attempt.caller_id' do
      voter.dispositioned(call_attempt)
      expect(voter.caller_id).to eq call_attempt.caller_id
    end

    it 'falls back to set caller_id to Voter#caller_session.caller.id' do
      call_attempt.caller_id = nil
      voter.dispositioned(call_attempt)
      expect(voter.caller_id).to eq caller_session.caller.id
    end

    it 'unsets caller_session_id' do
      voter.dispositioned(call_attempt)
      expect(voter.caller_session_id).to be_nil
    end
  end

  it "lists voters not called" do
    voter1 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    voter2 = create(:voter, :campaign => create(:campaign), :status=> Voter::Status::NOTCALLED)
    create(:voter, :campaign => create(:campaign), :status=> "Random")
    expect(Voter.by_status(Voter::Status::NOTCALLED)).to include(voter1)
    expect(Voter.by_status(Voter::Status::NOTCALLED)).to include(voter2)
  end

  it "returns only active voters" do
    active_voter = create(:voter, :active => true)
    inactive_voter = create(:voter, :active => false)
    expect(Voter.active).to include(active_voter)
  end

  it "returns voters from an enabled list" do
    voter_from_enabled_list = create(:voter, :voter_list => create(:voter_list, :enabled => true))
    voter_from_disabled_list = create(:voter, :disabled, :voter_list => create(:voter_list, :enabled => false))
    expect(Voter.enabled).to include(voter_from_enabled_list)
  end

  it "returns voters that have responded" do
    create(:voter)
    3.times { create(:voter, :result_date => Time.now) }
    expect(Voter.answered.size).to eq(3)
  end

  it "returns voters that have responded within a date range" do
    create(:voter)
    v1 = create(:voter, :result_date => DateTime.now)
    v2 = create(:voter, :result_date => 1.day.ago)
    v3 = create(:voter, :result_date => 2.days.ago)
    expect(Voter.answered_within(2.days.ago, 0.days.ago)).to eq([v1, v2, v3])
    expect(Voter.answered_within(2.days.ago, 1.day.ago)).to eq([v2, v3])
    expect(Voter.answered_within(1.days.ago, 1.days.ago)).to eq([v2])
  end

  it "returns voters who have responded within a time range" do
    v1 = create(:voter, :result_date => Time.new(2012, 2, 14, 10))
    v2 = create(:voter, :result_date => Time.new(2012, 2, 14, 15))
    v3 = create(:voter, :result_date => Time.new(2012, 2, 14, 20))
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 10), Time.new(2012, 2, 14, 12))).to eq([v1])
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 12), Time.new(2012, 2, 14, 23, 59, 59))).to eq([v2, v3])
    expect(Voter.answered_within_timespan(Time.new(2012, 2, 14, 0), Time.new(2012, 2, 14, 9, 59, 59))).to eq([])
  end

  describe 'answers' do
    let(:script) { create(:script) }
    let(:campaign) { create(:predictive, :script => script) }
    let(:voter) { create(:voter, :campaign => campaign, :caller_session => create(:caller_session, :caller => create(:caller))) }
    let(:question) { create(:question, :script => script) }
    let(:question_to_delete) { create(:question, :script => script) }
    let(:response) { create(:possible_response, :question => question) }
    let(:response_to_delete) { create(:possible_response, :question => question_to_delete) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }

    it "captures call responses" do
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\"}",call_attempt)
      expect(voter.answers.size).to eq(1)
    end

    it "puts voter back in the dial list if a retry response is detected" do
      another_response = create(:possible_response, :question => create(:question, :script => script), :retry => true)
      voter.persist_answers("{\"#{question.id}\":\"#{response.id}\",\"#{another_response.question.id}\":\"#{another_response.id}\" }", call_attempt)
      expect(voter.answers.size).to eq(2)
      expect(voter.reload.status).to eq(Voter::Status::RETRY)
    end

    it 'ignores questions that have been deleted but not processed' do
      answer_json = {
        "#{question.id}" => "#{response.id}",
        "#{question_to_delete.id}" => "#{response_to_delete.id}"
      }.to_json
      question_to_delete.destroy

      expect{ voter.persist_answers(answer_json, call_attempt) }.not_to raise_error
    end

    it "does not override old responses with newer ones" do
      question = create(:question, :script => script)
      retry_response = create(:possible_response, :question => question, :retry => true)
      valid_response = create(:possible_response, :question => question)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{retry_response.question.id}\":\"#{retry_response.id}\" }",call_attempt)
      expect(voter.answers.size).to eq(2)
      expect(voter.reload.status).to eq(Voter::Status::RETRY)
      voter.persist_answers("{\"#{response.question.id}\":\"#{response.id}\",\"#{valid_response.question.id}\":\"#{valid_response.id}\" }",call_attempt)
      expect(voter.reload.answers.size).to eq(4)
    end

    it "returns all questions unanswered" do
      answered_question = create(:question, :script => script)
      create(:answer, :voter => voter, :question => answered_question, :possible_response => create(:possible_response, :question => answered_question))
      pending_question = create(:question, :script => script)
      expect(voter.unanswered_questions).to eq([pending_question])
    end
  end

  describe "notes" do
    let(:script) { create(:script) }
    let(:note1) { create(:note, note: "Question1", script: script) }
    let(:note2) { create(:note, note: "Question2", script: script) }
    let(:call_attempt) { create(:call_attempt, :caller => create(:caller)) }
    let(:voter) { create(:voter, last_call_attempt: call_attempt) }

    it "captures call notes" do
      voter.persist_notes("{\"#{note1.id}\":\"tell\",\"#{note2.id}\":\"no\"}", call_attempt)
      expect(voter.note_responses.size).to eq(2)
    end
  end
end

# ## Schema Information
#
# Table name: `voters`
#
# ### Columns
#
# Name                          | Type               | Attributes
# ----------------------------- | ------------------ | ---------------------------
# **`id`**                      | `integer`          | `not null, primary key`
# **`phone`**                   | `string(255)`      |
# **`custom_id`**               | `string(255)`      |
# **`last_name`**               | `string(255)`      |
# **`first_name`**              | `string(255)`      |
# **`middle_name`**             | `string(255)`      |
# **`suffix`**                  | `string(255)`      |
# **`email`**                   | `string(255)`      |
# **`result`**                  | `string(255)`      |
# **`caller_session_id`**       | `integer`          |
# **`campaign_id`**             | `integer`          |
# **`account_id`**              | `integer`          |
# **`active`**                  | `boolean`          | `default(TRUE)`
# **`created_at`**              | `datetime`         |
# **`updated_at`**              | `datetime`         |
# **`status`**                  | `string(255)`      | `default("not called")`
# **`voter_list_id`**           | `integer`          |
# **`call_back`**               | `boolean`          | `default(FALSE)`
# **`caller_id`**               | `integer`          |
# **`result_digit`**            | `string(255)`      |
# **`attempt_id`**              | `integer`          |
# **`result_date`**             | `datetime`         |
# **`last_call_attempt_id`**    | `integer`          |
# **`last_call_attempt_time`**  | `datetime`         |
# **`num_family`**              | `integer`          | `default(1)`
# **`family_id_answered`**      | `integer`          |
# **`result_json`**             | `text`             |
# **`scheduled_date`**          | `datetime`         |
# **`address`**                 | `string(255)`      |
# **`city`**                    | `string(255)`      |
# **`state`**                   | `string(255)`      |
# **`zip_code`**                | `string(255)`      |
# **`country`**                 | `string(255)`      |
# **`skipped_time`**            | `datetime`         |
# **`priority`**                | `string(255)`      |
# **`lock_version`**            | `integer`          | `default(0)`
# **`enabled`**                 | `integer`          | `default(0), not null`
# **`voicemail_history`**       | `string(255)`      |
# **`blocked_number_id`**       | `integer`          |
# **`household_id`**            | `integer`          |
#
# ### Indexes
#
# * `index_on_blocked_number_id`:
#     * **`blocked_number_id`**
# * `index_priority_voters`:
#     * **`campaign_id`**
#     * **`enabled`**
#     * **`priority`**
#     * **`status`**
# * `index_voters_caller_id_campaign_id`:
#     * **`caller_id`**
#     * **`campaign_id`**
# * `index_voters_customid_campaign_id`:
#     * **`custom_id`**
#     * **`campaign_id`**
# * `index_voters_on_Phone_and_voter_list_id`:
#     * **`phone`**
#     * **`voter_list_id`**
# * `index_voters_on_attempt_id`:
#     * **`attempt_id`**
# * `index_voters_on_caller_session_id`:
#     * **`caller_session_id`**
# * `index_voters_on_campaign_id_and_active_and_status_and_call_back`:
#     * **`campaign_id`**
#     * **`active`**
#     * **`status`**
#     * **`call_back`**
# * `index_voters_on_campaign_id_and_status_and_id`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`id`**
# * `index_voters_on_household_id`:
#     * **`household_id`**
# * `index_voters_on_phone_campaign_id_last_call_attempt_time`:
#     * **`phone`**
#     * **`campaign_id`**
#     * **`last_call_attempt_time`**
# * `index_voters_on_status`:
#     * **`status`**
# * `index_voters_on_voter_list_id`:
#     * **`voter_list_id`**
# * `report_query`:
#     * **`campaign_id`**
#     * **`id`**
# * `voters_campaign_status_time`:
#     * **`campaign_id`**
#     * **`status`**
#     * **`last_call_attempt_time`**
# * `voters_enabled_campaign_time_status`:
#     * **`enabled`**
#     * **`campaign_id`**
#     * **`last_call_attempt_time`**
#     * **`status`**
#
