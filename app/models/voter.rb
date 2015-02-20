## 
# Models a Voter record. These records make-up the dial-pool.
#
# Columns:
# - `enabled` is a bitmask. Possible values: :list.
# - `active` is not currently in-use.
#
# When the Voter#enabled :list bit is set, the Voter is
# enabled and may be dialed depending on other settings.
#
class Voter < ActiveRecord::Base
  extend ImportProxy
  include Rails.application.routes.url_helpers
  include CallAttempt::Status

  acts_as_reportable

  UPLOAD_FIELDS = ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]

  module Status
    NOTCALLED = 'not called'
    RETRY     = 'retry'
    SKIPPED   = 'skipped'
  end

  belongs_to :account
  belongs_to :campaign
  belongs_to :voter_list, counter_cache: true
  belongs_to :household, counter_cache: true

  has_many :call_attempts
  has_many :custom_voter_field_values, autosave: true
  belongs_to :last_call_attempt, :class_name => "CallAttempt"
  belongs_to :caller_session
  has_many :answers
  has_many :note_responses

  validates_presence_of :household_id

  bitmask :enabled, as: [:list, :blocked], null: false

  scope :by_campaign, -> (campaign) { where(campaign_id: campaign) }

  scope :enabled, -> { with_enabled(:list) }
  scope :disabled, -> { without_enabled(:list) }

  scope :by_status, -> (status) { where(:status => status) }
  scope :active, -> { where(:active => true) }

  scope :answered, -> { where('voters.result_date is not null') }
  scope :answered_within, -> (from, to) { where(:result_date => from.beginning_of_day..(to.end_of_day)) }
  scope :answered_within_timespan, -> (from, to) { where(:result_date => from..to)}

  scope :completed, -> (campaign) {
    where('voters.status' => CallAttempt::Status.completed_list(campaign)).
    where('voters.call_back' => false)
  }

  scope :not_presentable, -> (campaign) {
    where(call_back: false).where(status: CallAttempt::Status.completed_list(campaign))
  }
  scope :presentable, -> (campaign) {
    where('call_back = ? OR status IN (?)', true, CallAttempt::Status.available_list(campaign))
  }

  cattr_reader :per_page
  @@per_page = 25

public
  # make activerecord-import work with bitmask_attributes
  def enabled=(raw_value)
    if raw_value.is_a?(Fixnum) && raw_value <= Voter.bitmasks[:enabled].values.sum
      self.send(:write_attribute, :enabled, raw_value)
    else
      values = raw_value.kind_of?(Array) ? raw_value : [raw_value]
      self.enabled.replace(values.reject{|value| value.blank?})
    end
  end

  def abandoned
    self.status = CallAttempt::Status::ABANDONED
    self.call_back = false
    self.caller_session = nil
    self.caller_id = nil
  end

  def do_not_call_back?
    return false if call_back_regardless_of_status?

    (not not_called?) and (not call_back?) and (not retry?)
  end

  def not_called?
    status == Voter::Status::NOTCALLED
  end

  def retry?
    status == Voter::Status::RETRY
  end

  def call_back_regardless_of_status?
    household.call_back_regardless_of_status?
  end

  def complete?
    # handle cases where caller drops message after which voter will be recorded as dispositioned
    return false if call_back_regardless_of_status?

    [
      CallAttempt::Status::SUCCESS,
      CallAttempt::Status::FAILED
    ].include?(status)
  end

  def cache?
    household.cache? and (
      not_called? or
      call_back? or
      retry? or
      (not complete?)
    )
  end

  def dispositioned(call_attempt)
    if campaign.nil?
      self.campaign = call_attempt.campaign
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Campaign[#{campaign.id}]")
    end

    if account.nil?
      self.account = campaign.account
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Account[#{account.id}]")
    end

    dial_queue             = CallFlow::DialQueue.new(campaign)
    self.status            = CallAttempt::Status::SUCCESS
    self.caller_id         = call_attempt.caller_id || caller_session.try(:caller).try(:id)
    self.caller_session_id = nil
  end

  def self.upload_fields
    ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state","zip_code", "country"]
  end

  def selected_custom_voter_field_values
    select_custom_fields = campaign.script.try(:selected_custom_fields)
    custom_voter_field_values.try(:select) { |cvf| select_custom_fields.include?(cvf.custom_voter_field.name) } if select_custom_fields.present?
  end

  def unanswered_questions
    campaign.script.questions.not_answered_by(self)
  end

  def question_not_answered
    unanswered_questions.first
  end

  def update_call_back(possible_responses)
    if possible_responses.any?(&:retry?)
      self.call_back = true
      self.status    = Voter::Status::RETRY
    else
      self.call_back = false
    end
  end

  def update_call_back_incrementally(possible_response, first_increment = false)
    if possible_response.retry?
      self.call_back = true
      self.status    = Voter::Status::RETRY
    else
      if updated_at.to_i <= 15.minutes.ago.to_i or first_increment
        self.call_back = false
      end
    end
  end

  # this is called from AnsweredJob and should run only
  # after #dispositioned has run (which is called from PersistCalls)
  # otherwise, the status of the voter will be overwritten.
  def persist_answers(questions, call_attempt)
    return if questions.nil?

    if campaign.nil?
      self.campaign = call_attempt.campaign
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Campaign[#{campaign.id}]")
    end

    if account.nil?
      self.account = campaign.account
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Account[#{account.id}]")
    end

    question_answers   = JSON.parse(questions)
    possible_responses = []
    question_answers.try(:each_pair) do |question_id, answer_id|
      begin
        question        = Question.find(question_id)
        voters_response = PossibleResponse.find(answer_id)
      rescue ActiveRecord::RecordNotFound => e
        # Questions & PossibleResponses may be deleted while a script is being used for dials.
        # This can lead to record not found errors but we don't want to throw away other questions/answers
        # that might still exist. So log the event and allow processing to continue.
        Rails.logger.error "#{e.message} Called from Voter#persist_answers for CallAttempt#{call_attempt.id}"
        next
      end

      answers.create({
        possible_response: voters_response,
        question: question,
        created_at: call_attempt.created_at,
        campaign: Campaign.find(campaign_id),
        caller: call_attempt.caller,
        call_attempt_id: call_attempt.id
      })

      possible_responses << voters_response
    end

    update_call_back(possible_responses)
    save
  end

  def persist_notes(notes_json, call_attempt)
    return if notes_json.nil?

    if campaign.nil?
      self.campaign = call_attempt.campaign
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Campaign[#{campaign.id}]")
    end

    if account.nil?
      self.account = campaign.account
      Rails.logger.error("AR-IMPORT RECOVERY: Voter[#{id}] Account[#{account.id}]")
    end

    notes = JSON.parse(notes_json)
    notes.try(:each_pair) do |note_id, note_res|
      note = Note.find(note_id)
      note_responses.create(response: note_res, note: Note.find(note_id), call_attempt_id: call_attempt.id, campaign_id: campaign_id)
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
