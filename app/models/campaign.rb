require Rails.root.join("lib/twilio_lib")

##
# Attributes
# +use_recordings+ boolean
#     Truthy value tells system to auto-drop a message when machine is detected.
#     Falsy value tells system to hang-up when machine is detected.
#
# +recording_id+ integer
#     Reference to recorded message ID that will drop (either automatically or manually)
#
# +answering_machine_detect+ boolean
#     Truthy value tells system to enable Twilio AMD and increase ring timeout to 30 seconds
#     Falsey value tells system to not enable Twilio AMD and maintain ring timeout of 15 seconds
#
# +call_back_after_voicemail_delivery+ boolean
#     Truthy value tells system to recycle contacts after a message has been dropped (only one message should ever be left as of June 20, 2014)
#     Falsey value tells system to not recycle contacts after a message has been dropped (contact will not be dialed again)
#
# +caller_can_drop_message_manually+ boolean
#     Truthy value tells system to present callers with the ability to click to drop a message when on active calls
#     Falsey value tells system to deny callers ability to click to drop a message
#
class Campaign < ActiveRecord::Base
  include Deletable

  acts_as_reportable

  attr_accessible :type, :name, :caller_id, :script_id, :acceptable_abandon_rate, :time_zone,
                  :start_time, :end_time, :recycle_rate, :answering_machine_detect,
                  :voter_lists_attributes, :use_recordings, :recording_id,
                  :call_back_after_voicemail_delivery, :caller_can_drop_message_manually


  has_many :caller_sessions
  has_many :caller_sessions_on_call, conditions: {on_call: true}, class_name: 'CallerSession'
  has_many :voter_lists, :conditions => {:active => true}
  has_many :all_voters, :class_name => 'Voter'
  has_many :call_attempts
  has_many :transfer_attempts
  has_many :callers
  has_one :simulated_values
  has_many :answers
  has_many :note_responses
  has_many :caller_groups
  belongs_to :script
  belongs_to :account
  belongs_to :recording
  has_many :downloaded_reports

  accepts_nested_attributes_for :voter_lists

  delegate :questions_and_responses, :to => :script

  scope :manual
  scope :for_account, lambda { |account| {:conditions => ["account_id = ?", account.id]} }
  scope :for_script, lambda { |script| {:conditions => ["script_id = ?", script.id]} }
  scope :active, where(:active => true)
  scope :with_running_caller_sessions, {
      :select => "distinct campaigns.*",
      :joins => "inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)",
      :conditions => {"caller_sessions.on_call" => true}
  }

  scope :with_non_running_caller_sessions, {
      :select => "distinct campaigns.*",
      :joins => "inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)",
      :conditions => {"caller_sessions.on_call" => false}
  }

  scope :for_caller, lambda { |caller| joins(:caller_sessions).where(caller_sessions: {caller_id: caller}) }
  scope :by_type, lambda { |type| where(type:  type) }


  validates :name, :presence => true
  validates :caller_id, :presence => true
  validates :caller_id, :numericality => {}, :length => {:minimum => 10, :maximum => 10}, :unless => Proc.new{|campaign| campaign.caller_id && campaign.caller_id.start_with?('+')}
  validates :script, :presence => true
  validates :type, :presence => true, :inclusion => {:in => ['Preview', 'Power', 'Predictive']}
  validates :acceptable_abandon_rate,
            :numericality => {:greater_than_or_equal_to => 0.01, :less_than_or_equal_to => 0.10},
            :allow_blank => true
  validates :recycle_rate, :presence => true, :numericality => true
  validates :time_zone, :presence => true, :inclusion => {:in => ActiveSupport::TimeZone.zones_map.map {|z| z.first}}
  validates :start_time, :presence => true
  validates :end_time, :presence => true
  validate :set_caller_id_error_msg
  validate :campaign_type_changed, on: :update
  validate :no_caller_assigned_on_deletion
  validate :campaign_type_based_on_subscription
  cattr_reader :per_page
  @@per_page = 25

  before_validation :sanitize_caller_id
  before_save :sanitize_message_service_settings

private
  def sanitize_message_service_settings
    if use_recordings? and !answering_machine_detect?
      self.use_recordings = false
    end

    if call_back_after_voicemail_delivery? and !use_recordings? and !caller_can_drop_message_manually?
      self.call_back_after_voicemail_delivery = false
    end

    true # make sure to not halt callback chain for any reason from here
  end

public

  module Type
    PREVIEW = "Preview"
    PREDICTIVE = "Predictive"
    POWER = "Power"
  end

  def self.preview_power_campaign?(campaign_type)
    [Type::PREVIEW, Type::POWER].include?(campaign_type)
  end

  def self.predictive_campaign?(campaign_type)
    Type::PREDICTIVE == campaign_type
  end

  def blocked_numbers
    @blocked_numbers ||= account.blocked_numbers.for_campaign(self).pluck(:number)
  end

  def new_campaign
    raise "Deprecated: Campaign#new_campaign"
    new_record?
  end

  def ability
    @ability ||= Ability.new(account)
  end

  def campaign_type_based_on_subscription
    ttype = type.blank? ? nil : type.constantize # Type cast for cancan
    unless ability.can? :manage, ttype
      errors.add(:base, 'Your subscription does not allow this mode of Dialing.')
    end
    type.to_s
  end

  def no_caller_assigned_on_deletion
    if active_change == [true, false] && callers.active.any?
      errors.add(:base, 'There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.')
    end
  end

  def within_recycle_rate?(obj)
    unless obj.respond_to? :last_call_attempt_time
      raise ArgumentError, "First and only arg should respond to :last_call_attempt_time"
    end
    obj.last_call_attempt_time.present? &&
    obj.last_call_attempt_time >= recycle_rate.hours.ago
  end

  def set_caller_id_error_msg
      if errors[:caller_id].any?
        errors[:caller_id].clear
        errors.add(:base, 'Caller ID must be a 10-digit North American phone number or begin with "+" and the country code')
      end
    end

  def campaign_type_changed
    if type_changed? && callers_log_in?
      errors.add(:base, 'You cannot change dialing modes while callers are logged in.')
    end
  end

  def is_preview_or_power
    raise "Deprecated: Campaign#is_preview_or_power"
    type == Type::PREVIEW || type == Type::PROGRESSIVE
  end

  def sanitize_caller_id
    self.caller_id = Voter.sanitize_phone(self.caller_id)
  end

  def continue_on_amd
    answering_machine_detect && use_recordings
  end

  def hangup_on_amd
    answering_machine_detect && !use_recordings
  end

  def fit_to_dial?
    account.funds_available? && within_calling_hours?
  end

  def within_calling_hours?
    not time_period_exceeded?
  end

  def time_period_exceeded?
    return true if start_time.nil? || end_time.nil?
    if start_time.hour < end_time.hour
      !(start_time.hour <= Time.now.utc.in_time_zone(time_zone).hour && end_time.hour > Time.now.utc.in_time_zone(time_zone).hour)
    else
      !(start_time.hour >= Time.now.utc.in_time_zone(time_zone).hour || end_time.hour < Time.now.utc.in_time_zone(time_zone).hour)
    end
  end
  alias :outside_calling_hours? :time_period_exceeded?

  def callers_log_in?
    caller_sessions.on_call.size > 0
  end

  def as_time_zone
    time_zone.nil? ? nil : ActiveSupport::TimeZone.new(time_zone)
  end

  def first_call_attempt_time
    call_attempts.first.try(:created_at)
  end

  def last_call_attempt_time
    call_attempts.from("call_attempts use index (index_call_attempts_on_campaign_id)").last.try(:created_at)
  end

  def voters_called
    raise "Deprecated: Campaign#voters_called"
    Voter.find_all_by_campaign_id(self.id, :select=>"id", :conditions=>"status <> 'not called'")
  end


  def voters_count(status=nil, include_call_retries=true)
    raise "Deprecated: Campaign#voters_count"

    active_lists_ids = VoterList.where(campaign_id: self.id, active: true, enabled: true).pluck(:id)
    return [] if active_lists_ids.empty?
    Voter.where(active: true, voter_list_id: active_lists_ids).
      where(["status = ? OR (call_back = 1 AND last_call_attempt_time < (Now() - INTERVAL 180 MINUTE))", status]).count
  end


  def voters(status=nil, include_call_retries=true, limit=300)
    raise "Deprecated: Campaign#voters"

    voters_returned = []
    return voters_returned if !self.account.activated? || self.caller_id.blank?
    active_list_ids = VoterList.active_voter_list_ids(self.id)
    return voters_returned if active_list_ids.empty?
    voters_returned.concat(Voter.to_be_called(id, active_list_ids, status, recycle_rate))
    voters_returned.uniq
  end


  def callers_available_for_call
    raise "Deprecated: Campaign#callers_available_for_call"
    RedisAvailableCaller.count(self.id)
  end

  def average(array)
    raise "Deprecated: Campaign#average"
    array.sum.to_f / array.size
  end

  ##
  # Reporting methods
  #
  def answers_result(from_date, to_date)
    # load question ids related to the campaign, from answers
    question_ids = Answer.where(campaign_id: self.id).uniq.pluck(:question_id)
    answer_count = Answer.select("possible_response_id").from('answers use index (index_answers_on_campaign_created_at_possible_response)').
        where("campaign_id = ?", self.id).within(from_date, to_date).group("possible_response_id").count
    total_answers = Answer.where("campaign_id = ?",self.id).within(from_date, to_date).group("question_id").count
    questions_data = Question.where(id: question_ids).includes(:possible_responses).each_with_object({}) do |question, memo|
      memo[question.script_id] ||= []
      memo[question.script_id] << question
    end
    Script.where(id: questions_data.keys).each_with_object({}) do |script, result|
      result[script.id] = {script: script.name, questions: {}}
      questions_data[script.id].each do |question|
        result[script.id][:questions][question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(answer_count, total_answers) }
        result[script.id][:questions][question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.select { |x| x.value == "[No response]"}.any?
      end
    end
  end

  def transfers(from_date, to_date)
    result = {}
    attempts = transfer_attempts.within(from_date, to_date, id)
    unless attempts.blank?
      result = TransferAttempt.aggregate(attempts)
    end
    result
  end

  def transfer_time(from_date, to_date)
    transfer_attempts.between(from_date, to_date).sum('ceil(tDuration/60)').to_i
  end

  def voicemail_time(from_date, to_date)
    call_attempts.between(from_date, to_date).with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(tDuration/60)').to_i
  end

  def abandoned_calls_time(from_date, to_date)
    call_attempts.between(from_date, to_date).with_status([CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i
  end

  def leads_available_now
    sanitize_dials(all_voters.enabled.avialable_to_be_retried(recycle_rate).count  + all_voters.by_status(CallAttempt::Status::ABANDONED).count)
  end

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end

  def cost_per_minute
    raise "Deprecated: Campaign#cost_per_minute"
    0.09
  end

  def callers_status
    campaign_callers = caller_sessions.on_call
    on_hold = campaign_callers.select {|caller| (caller.on_call? && caller.available_for_call? )}
    on_call = campaign_callers.select {|caller| (caller.on_call? && !caller.available_for_call?)}
    [campaign_callers.size, on_hold.size, on_call.size]
  end

  def call_status
    raise "Deprecated: Campaign#call_status"

    wrap_up = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::SUCCESS).not_wrapped_up.size
    ringing_lines = call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    live_lines = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::INPROGRESS).size
    [wrap_up, ringing_lines, live_lines]
  end

  def current_status
    current_caller_sessions = caller_sessions.on_call.includes(:attempt_in_progress)
    callers_logged_in = current_caller_sessions.size
    if callers_logged_in.zero?
      status_count  = [0,0,0]
    else
      status_count = RedisStatus.count_by_status(self.id, current_caller_sessions.collect{|x| x.id})
    end

    ringing_lines = call_attempts.with_status(CallAttempt::Status::RINGING).between(15.seconds.ago, Time.now).size
    num_remaining = all_voters.by_status('not called').enabled.count
    num_available = leads_available_now + num_remaining
    {callers_logged_in: callers_logged_in, on_call: status_count[1], wrap_up: status_count[2], on_hold: status_count[0], ringing_lines: ringing_lines, available: num_available  }
  end

  def current_callers_status
    callers = []
    current_caller_sessions = caller_sessions.on_call.includes(:caller)
    current_caller_sessions.each do |cs|
      value = RedisStatus.state_time(self.id, cs.id)
      if value.present?
        callers << {id: cs.id, caller_id: cs.caller.id, name: cs.caller.identity_name, status: value[0],
         time_in_status: value[1], campaign_name: self.name, campaign_id: self.id}
      end
    end
    callers
  end
end

# ## Schema Information
#
# Table name: `campaigns`
#
# ### Columns
#
# Name                                      | Type               | Attributes
# ----------------------------------------- | ------------------ | ---------------------------
# **`id`**                                  | `integer`          | `not null, primary key`
# **`campaign_id`**                         | `string(255)`      |
# **`name`**                                | `string(255)`      |
# **`account_id`**                          | `integer`          |
# **`script_id`**                           | `integer`          |
# **`active`**                              | `boolean`          | `default(TRUE)`
# **`created_at`**                          | `datetime`         |
# **`updated_at`**                          | `datetime`         |
# **`caller_id`**                           | `string(255)`      |
# **`type`**                                | `string(255)`      |
# **`recording_id`**                        | `integer`          |
# **`use_recordings`**                      | `boolean`          | `default(FALSE)`
# **`calls_in_progress`**                   | `boolean`          | `default(FALSE)`
# **`recycle_rate`**                        | `integer`          | `default(1)`
# **`answering_machine_detect`**            | `boolean`          |
# **`start_time`**                          | `time`             |
# **`end_time`**                            | `time`             |
# **`time_zone`**                           | `string(255)`      |
# **`acceptable_abandon_rate`**             | `float`            |
# **`call_back_after_voicemail_delivery`**  | `boolean`          | `default(FALSE)`
# **`caller_can_drop_message_manually`**    | `boolean`          | `default(FALSE)`
#
