require Rails.root.join("lib/twilio_lib")

class CallAttempt < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include SidekiqEvents
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  belongs_to :caller_session
  has_one :transfer_attempt
  belongs_to :call
  has_many :answers
  has_many :note_responses

  scope :dial_in_progress, where('call_end is null')
  scope :not_wrapped_up, where('wrapup_time is null')
  scope :for_campaign, lambda { |campaign| {:conditions => ["campaign_id = ?", campaign.id]}  unless campaign.nil?}
  scope :for_caller, lambda { |caller| {:conditions => ["caller_id = ?", caller.id]}  unless caller.nil?}

  scope :for_status, lambda { |status| {:conditions => ["call_attempts.status = ?", status]} }
  scope :between, lambda { |from, to| where(:created_at => (from..to)) }
  scope :without_status, lambda { |statuses| {:conditions => ['status not in (?)', statuses]} }
  scope :with_status, lambda { |statuses| {:conditions => ['status in (?)', statuses]} }
  scope :results_not_processed, lambda { where(:voter_response_processed => "0", :status => Status::SUCCESS).where('wrapup_time is not null') }

  scope :undebited, where(debited: false)
  scope :successful_call, where("status NOT IN ('No answer', 'No answer busy signal', 'Call failed')")
  scope(:with_time_and_duration,
        where('tStartTime IS NOT NULL').
        where('tEndTime IS NOT NULL').
        where('tDuration IS NOT NULL')
  )
  scope :debit_pending, undebited.successful_call.with_time_and_duration

  scope :with_recording, where('recording_id IS NOT NULL')
  scope :with_manual_message_drop, with_recording.where('recording_delivered_manually=?', true)
  scope :with_auto_message_drop, with_recording.where('recording_delivered_manually=?', false)
  scope :not_ringing, lambda{ where('status <> ?', Status::RINGING) }

  def self.report_recording_url(url)
    "#{url.gsub("api.twilio.com", "recordings.impactdialing.com")}.mp3" if url
  end

  def report_recording_url
    CallAttempt.report_recording_url(self.recording_url)
  end

  def update_recording!(delivered_manually=false)
    voter.update_voicemail_history
    voter.update_call_back_after_message_drop
    voter.save

    self.recording_id                 = campaign.recording_id
    self.recording_delivered_manually = delivered_manually
    self.save!
  end

  def duration
    return nil unless connecttime
    ((call_end || Time.now) - connecttime).to_i
  end

  def succeeded?
    return status == CallAttempt::Status::SUCCESS
  end

  def duration_wrapped_up
    ((wrapup_time || Time.now) - (self.connecttime || Time.now)).to_i
  end

  def time_to_wrapup
    ((wrapup_time || Time.now) - (self.call_end || Time.now)).to_i
  end

  def duration_rounded_up
    ((duration || 0) / 60.0).ceil
  end

  def minutes_used
    return 0 if self.tDuration.blank?
    (self.tDuration/60.0).ceil
  end

  def client
    campaign.client
  end

  def self.wrapup_calls(caller_id)
    CallAttempt.not_wrapped_up.where(caller_id: caller_id).update_all(wrapup_time: Time.now)
  end

  def abandoned(time)
    self.status = CallAttempt::Status::ABANDONED
    self.connecttime = time
    self.call_end = time
  end

  def end_answered_by_machine(connect_time, end_time)
    self.connecttime = connect_time
    self.wrapup_time = end_time
    self.call_end    = end_time
    self.status      = AnsweringMachineAgent.new(voter).call_status
  end

  def end_unanswered_call(call_status, time)
    self.status = CallAttempt::Status::MAP[call_status]
    self.wrapup_time = time
    self.call_end = time
  end

  def disconnect_call(time, duration, url, caller_id)
    self.status = CallAttempt::Status::SUCCESS
    self.call_end =  time
    self.recording_duration = duration
    self.recording_url = url
    self.caller_id = caller_id
  end

  def schedule_for_later(date)
    scheduled_date = DateTime.strptime(date, "%m/%d/%Y %H:%M").to_time
    self.status = Status::SCHEDULED
    self.scheduled_date = scheduled_date
  end

  def wrapup_now(time, caller_type)
    self.wrapup_time = time
    if caller_type == CallerSession::CallerType::PHONE && caller.is_phones_only
      self.voter_response_processed = true
    end
  end

  def connect_caller_to_lead(callee_dc)
    caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign_id, callee_dc)
    unless caller_session_id.nil?
      loaded_caller_session = CallerSession.find_by_id_cached(caller_session_id)
      begin
        loaded_caller_session.update_attributes(attempt_in_progress: self, voter_in_progress: self.voter, available_for_call: false)
      rescue ActiveRecord::StaleObjectError
        RedisOnHoldCaller.remove_caller_session(campaign_id, caller_session_id, callee_dc)
        RedisOnHoldCaller.add_to_bottom(campaign_id, caller_session_id, callee_dc)
      end
    end
  end

  def connect_call
    self.update_attributes(connecttime: Time.now)
    RedisStatus.set_state_changed_time(campaign.id, "On call", caller_session_id)
  end

  def not_wrapped_up?
    wrapup_time.nil?
  end



  def self.time_on_call(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('tDuration').to_i
  end

  def self.time_in_wrapup(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      with_status([CallAttempt::Status::SUCCESS])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('TIMESTAMPDIFF(SECOND ,tEndTime,wrapup_time)').to_i
  end

  def self.lead_time(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('ceil(tDuration/60)').to_i
  end

  ##
  # Statuses that get called back:
  # - VOICEMAIL
  # - NOANSWER
  # - ABANDONED
  # - BUSY
  # - HANGUP
  # - CANCELLED
  # - SCHEDULED
  #
  module Status
    VOICEMAIL = 'Message delivered'
    SUCCESS = 'Call completed with success.'
    INPROGRESS = 'Call in progress'
    NOANSWER = 'No answer'
    ABANDONED = "Call abandoned"
    BUSY = "No answer busy signal"
    FAILED = "Call failed"
    HANGUP = "Hangup or answering machine" # Used when answered by machine and there is no recording to play for the message.
    READY = "Call ready to dial"
    CANCELLED = "Call cancelled"
    SCHEDULED = 'Scheduled for later'
    RINGING = "Ringing"

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED}
    ALL = MAP.values
    RETRY = [NOANSWER, BUSY, FAILED]
    ANSWERED =  [INPROGRESS, SUCCESS]

    def self.retry_list(campaign)
      statuses = [ABANDONED, BUSY, NOANSWER, HANGUP, Voter::Status::RETRY, Voter::Status::SKIPPED]

      if campaign.call_back_after_voicemail_delivery?
        statuses << VOICEMAIL
      end

      statuses
    end

    def self.in_progress_list
      [RINGING, READY, INPROGRESS]
    end

    def self.not_available_list(campaign)
      statuses = [INPROGRESS, RINGING, READY]
      statuses + completed_list(campaign)
    end

    def self.available_list(campaign)
      statuses = [Voter::Status::NOTCALLED]
      statuses + retry_list(campaign)
    end

    def self.completed_list(campaign)
      statuses = [SUCCESS, FAILED]

      # When campaign is set to call people back after dropping message
      # then the fact a message was dropped does NOT indicate a completed call.
      unless campaign.call_back_after_voicemail_delivery?
        statuses << VOICEMAIL
      end

      statuses
    end

    def self.not_dialed_list
      [RINGING, READY, Voter::Status::NOTCALLED]
    end

    def self.answered_list
      [SUCCESS, SCHEDULED, Voter::Status::RETRY]
    end

    def self.machine_answered_list
      [HANGUP, VOICEMAIL]
    end
  end

  def redirect_caller
    unless caller_session_id.nil?
      enqueue_call_flow(RedirectCallerJob, [caller_session_id])
    end
  end

  def end_caller_session
    unless caller_session_id.nil?
      caller_session.stop_calling
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
