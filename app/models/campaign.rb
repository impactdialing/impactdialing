require Rails.root.join("lib/twilio_lib")
require 'impact_platform/metrics'
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

  belongs_to :script
  belongs_to :account
  belongs_to :recording
  has_many :caller_sessions
  has_many :caller_sessions_on_call, -> { where on_call: true }, class_name: 'CallerSession'
  has_many :voter_lists, -> { where(active: true) }
  has_many :list_activities, -> { where(active: true).order('id DESC') }, class_name: 'VoterList'
  has_many :lists, class_name: 'VoterList'
  has_many :all_voters, :class_name => 'Voter'
  has_many :call_attempts
  has_many :transfer_attempts
  has_many :callers
  has_many :answers
  has_many :note_responses
  has_many :caller_groups
  has_many :downloaded_reports
  has_many :households

  accepts_nested_attributes_for :voter_lists

  delegate :questions_and_responses, :to => :script

  scope :for_account, -> (account) { where(["account_id = ?", account.id]) }
  scope :for_script, -> (script) { where(["script_id = ?", script.id]) }
  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false) }
  scope :with_running_caller_sessions, -> {
    select("distinct campaigns.*").
    joins("inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)").
    where("caller_sessions.on_call" => true)
  }

  scope :with_non_running_caller_sessions, -> {
    select("distinct campaigns.*").
    joins("inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)").
    where("caller_sessions.on_call" => false)
  }

  scope :for_caller, lambda { |caller| joins(:caller_sessions).where(caller_sessions: {caller_id: caller}) }
  scope :by_type, lambda { |type| where(type:  type) }


  validates :name, :presence => true, :length => {:maximum => 200}
  validates :caller_id, :presence => true
  validates :caller_id, :numericality => true, :length => {:minimum => 10, :maximum => 10}, :unless => :skip_caller_id_validation? #fixme we don't support int'l currently (except australia), plus this is a poor validation - if an invalid number is entered, we will just silently fail to make calls and report status Failed for all calls
  validates :script, :presence => true
  validates :type, :presence => true, :inclusion => {:in => ['Preview', 'Power', 'Predictive']}
  validates :acceptable_abandon_rate,
            :numericality => {:greater_than_or_equal_to => 0.01, :less_than_or_equal_to => 0.10},
            :allow_blank => true
  validates :recycle_rate, {
    :numericality => {
      :greater_than_or_equal_to => 1,
      :message => 'must be a number and at least 1'
    }
  }
  validates :time_zone, :presence => true, :inclusion => {:in => ActiveSupport::TimeZone.zones_map.map {|z| z.first}}
  validates :start_time, :presence => true
  validates :end_time, :presence => true
  validate :set_caller_id_error_msg
  validate :campaign_type_changed, on: :update
  validate :campaign_type_based_on_subscription
  cattr_reader :per_page
  @@per_page = 25

  before_validation :sanitize_caller_id, :if => :caller_id
  before_save :sanitize_message_service_settings
  before_save :flag_archive_changes
  after_save :publish_archival_notification

  delegate :last_dial_time, to: :inflight_stats
  delegate :update_last_dial_time, to: :inflight_stats

  def simulated_values
    @simulated_values = SimulatedValues.where(campaign: self).order(:created_at).last
  end

  def simulated_values=(values)
    @simulated_values = values
  end

private
  # flag archive-related changes for use by notification after changes have persisted
  def flag_archive_changes
    @archive_flag = nil

    case active_change
    when [true, false]
      @archive_flag = 'campaigns.archived'
    end

    return true
  end

  def publish_archival_notification
    unless @archive_flag.nil?
      ActiveSupport::Notifications.instrument(@archive_flag, campaign: self)
    end

    return true
  end

  def skip_caller_id_validation?
    ENV['INTERNATIONAL'] && caller_id && caller_id.start_with?('+')
  end

  def sanitize_caller_id
    self.caller_id = caller_id[1..-1] if self.caller_id[0] == '1'
    country_mark   = self.caller_id.start_with?('+') ? '+' : ''
    self.caller_id = "#{country_mark}#{PhoneNumber.sanitize(self.caller_id)}"
  end

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

  def new_voter_list(attrs={})
    voter_lists.new(attrs.merge({
      account_id: account_id
    }))
  end

  def inflight_stats
    @inflight_stats ||= Twillio::InflightStats.new(self)
  end

  def metric_source
    source = []
    source << "ac-#{self.account_id}"
    source << "ca-#{self.id}"
    source << "dm-#{self.type.downcase}"
    source
  end

  def timing(name, &block)
    bench_start = Time.now.to_f

    yield

    bench_end = Time.now.to_f

    ImpactPlatform::Metrics.measure(name, (bench_end - bench_start), metric_source.join('.'))
  end

  def debug_number(name, counter, &block)
    source = metric_source.join('.')
    prefix = "debug.dialer.dial_queue.number_#{name}"

    ImpactPlatform::Metrics.sample("#{prefix}.#{counter}.before", send("#{counter}_count"), source)

    result = yield

    ImpactPlatform::Metrics.sample("#{prefix}.#{counter}.after", result, source)
  end

  def debug_number_ringing(counts)
    source = metric_source.join('.')
    prefix = "debug.dialer.dial_queue.number_ringing"
    ImpactPlatform::Metrics.sample("#{prefix}.presented.before", counts[0], source)
    ImpactPlatform::Metrics.sample("#{prefix}.ringing.before", counts[1], source)
    ImpactPlatform::Metrics.sample("#{prefix}.presented.after", counts[2], source)
    ImpactPlatform::Metrics.sample("#{prefix}.ringing.after", counts[3], source)
  end

  def number_not_ringing
    debug_number('not_ringing', 'ringing') do
      inflight_stats.dec('ringing')
    end
  end

  def number_presented(n)
    raise "NotImplemented"
  end

  def number_ringing
    raise "NotImplemented"
  end

  def number_failed
    raise "NotImplemented"
  end

  def presented_count
    current_count = inflight_stats.get('presented')
    # hacky fix for negative presented count - likely caused by caller_session.rb:183
    if current_count < 0
      inflight_stats.incby('presented', current_count.abs)
    else
      current_count
    end
  end

  def ringing_count
    current_count = inflight_stats.get('ringing')
    # hacky fix for negative ringing count
    if current_count < 0
      puts "Negative ringing for campaign #{id}: #{current_count}"
      inflight_stats.incby('ringing', current_count.abs)
    else
      current_count
    end
  end

  def household_sequence
    call_list.stats['number_sequence'].to_i
  end

  def lead_sequence
    call_list.stats['lead_sequence'].to_i
  end

  def custom_id_register_key_base
    call_list.custom_id_register_key_base
  end

  def call_list
    @call_list ||= CallList.new(self)
  end

  def requires_custom_ids?
    lists.count.zero? || using_custom_ids?
  end

  def can_use_custom_ids?
    lists.count.zero? or using_custom_ids?
  end

  def cannot_use_custom_ids?
    (not lists.count.zero?) and (not using_custom_ids?)
  end

  def using_custom_ids?
    lists.first.maps_custom_id?
  end

  def dial_queue
    @dial_queue ||= CallFlow::DialQueue.new(self)
  end

  def cached?
    dial_queue.exists?
  end

  def archived?
    not active?
  end

  def self.preview_power_campaign?(campaign_type)
    [Type::PREVIEW, Type::POWER].include?(campaign_type)
  end

  def self.predictive_campaign?(campaign_type)
    Type::PREDICTIVE == campaign_type
  end

  def predictive?
    self.class.predictive_campaign?(type)
  end

  def blocked_numbers
    @blocked_numbers ||= account.blocked_numbers.for_campaign(self).pluck(:number)
  end

  def find_dnc_match_id(phone)
    account.blocked_numbers.matching(self, phone).pluck(:id)
  end

  def new_campaign
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#new_campaign"
    new_record?
  end

  def ability
    @ability = Ability.new(account)
  end

  def campaign_type_based_on_subscription
    ttype = type.blank? ? nil : type.constantize # Type cast for cancan
    unless ability.can? :manage, ttype
      errors.add(:base, 'Your subscription does not allow this mode of Dialing.')
    end
    type.to_s
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
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#is_preview_or_power"
    type == Type::PREVIEW || type == Type::PROGRESSIVE
  end

  def continue_on_amd
    answering_machine_detect && use_recordings
  end

  def hangup_on_amd
    answering_machine_detect && !use_recordings
  end

  def fit_to_dial?
    account.funds_available? && within_calling_hours? && ability.can?(:access_dialer, Caller)
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

  def callers_assigned?
    callers.count > 0
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

  def voters_count(status=nil, include_call_retries=true)
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#voters_count"

    active_lists_ids = VoterList.where(campaign_id: self.id, active: true, enabled: true).pluck(:id)
    return [] if active_lists_ids.empty?
    Voter.where(active: true, voter_list_id: active_lists_ids).
      where(["status = ? OR (call_back = 1 AND last_call_attempt_time < (Now() - INTERVAL 180 MINUTE))", status]).count
  end


  def voters(status=nil, include_call_retries=true, limit=300)
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#voters"

    voters_returned = []
    return voters_returned if !self.account.activated? || self.caller_id.blank?
    active_list_ids = VoterList.active_voter_list_ids(self.id)
    return voters_returned if active_list_ids.empty?
    voters_returned.concat(Voter.to_be_called(id, active_list_ids, status, recycle_rate))
    voters_returned.uniq
  end


  def callers_available_for_call
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#callers_available_for_call"
    RedisAvailableCaller.count(self.id)
  end

  def average(array)
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#average"
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
    attempts = transfer_attempts.includes(:transfer).within(from_date, to_date, id)
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

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end

  def cost_per_minute
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#cost_per_minute"
    0.09
  end

  def callers_status
    campaign_callers = caller_sessions.on_call
    on_hold = campaign_callers.select {|caller| (caller.on_call? && caller.available_for_call? )}
    on_call = campaign_callers.select {|caller| (caller.on_call? && !caller.available_for_call?)}
    [campaign_callers.size, on_hold.size, on_call.size]
  end

  def call_status
    Rails.logger.info "Deprecated ImpactDialing Method: Campaign#call_status"

    wrap_up = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::SUCCESS).not_wrapped_up.size
    ringing_lines = call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    live_lines = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::INPROGRESS).size
    [wrap_up, ringing_lines, live_lines]
  end

  def current_status
    current_caller_sessions = caller_sessions.on_call
    callers_logged_in       = current_caller_sessions.size
    if callers_logged_in.zero?
      status_count  = [0,0,0]
    else
      status_count = RedisStatus.count_by_status(self.id, current_caller_sessions.collect{|x| x.id})
    end

    ringing_lines = inflight_stats.get('ringing')
    available     = dial_queue.available.size

    return {
      callers_logged_in: callers_logged_in,
      on_call: status_count[1],
      wrap_up: status_count[2],
      on_hold: status_count[0],
      ringing_lines: ringing_lines,
      available: available
    }
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
