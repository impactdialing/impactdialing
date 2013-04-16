require Rails.root.join("lib/twilio_lib")

class Campaign < ActiveRecord::Base
  include Deletable

  attr_accessible :type, :name, :caller_id, :script_id, :acceptable_abandon_rate, :time_zone, :start_time, :end_time, :recycle_rate, :answering_machine_detect, :voter_lists_attributes, :use_recordings, :recording_id


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


  validates :name, :presence => true
  validates :caller_id, :presence => true
  validates :caller_id, :numericality => {}, :length => {:minimum => 10, :maximum => 10}, :unless => Proc.new{|campaign| campaign.caller_id && campaign.caller_id.start_with?('+')}
  validates :script, :presence => true
  validates :type, :presence => true, :inclusion => {:in => ['Preview', 'Progressive', 'Predictive']}
  validates :acceptable_abandon_rate,
            :numericality => {:greater_than_or_equal_to => 0.01, :less_than_or_equal_to => 0.10},
            :allow_blank => true
  validates :recycle_rate, :presence => true, :numericality => true
  validates :time_zone, :presence => true, :inclusion => {:in => ActiveSupport::TimeZone.zones_map.map {|z| z.first}}
  validates :start_time, :presence => true
  validates :end_time, :presence => true
  validate :set_caller_id_error_msg
  validate :campaign_type_changed, on: :update
  validate :script_changed_called
  validate :no_caller_assigned_on_deletion
  cattr_reader :per_page
  @@per_page = 25

  before_validation :sanitize_caller_id

  module Type
    PREVIEW = "Preview"
    PREDICTIVE = "Predictive"
    PROGRESSIVE = "Progressive"
  end

  def self.preview_power_campaign?(campaign_type)
    [Type::PREVIEW, Type::PROGRESSIVE].include?(campaign_type)
  end

  def self.predictive_campaign?(campaign_type)
    Type::PREDICTIVE == campaign_type
  end


  def new_campaign
    new_record?
  end

  def no_caller_assigned_on_deletion
    if active_change == [true, false] && callers.active.any?
      errors.add(:base, 'There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.')
    end
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

  def script_changed_called
    if !new_record? && script_id_changed? && call_attempts.count > 0
      errors.add(:base, I18n.t(:script_cannot_be_modified))
    end
  end


  def is_preview_or_progressive
    type == Type::PREVIEW || type == Type::PROGRESSIVE
  end

  def sanitize_caller_id
    self.caller_id = Voter.sanitize_phone(self.caller_id)
  end

  def time_period_exceeded?
    return true if start_time.nil? || end_time.nil?
    if start_time.hour < end_time.hour
      !(start_time.hour <= Time.now.utc.in_time_zone(time_zone).hour && end_time.hour > Time.now.utc.in_time_zone(time_zone).hour)
    else
      !(start_time.hour >= Time.now.utc.in_time_zone(time_zone).hour || end_time.hour < Time.now.utc.in_time_zone(time_zone).hour)
    end
  end


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
    Voter.find_all_by_campaign_id(self.id, :select=>"id", :conditions=>"status <> 'not called'")
  end


  def voters_count(status=nil, include_call_retries=true)
    active_lists_ids = VoterList.where(campaign_id: self.id, active: true, enabled: true).pluck(:id)
    return [] if active_lists_ids.empty?
    Voter.where(active: true, voter_list_id: active_lists_ids).
      where(["status = ? OR (call_back = 1 AND last_call_attempt_time < (Now() - INTERVAL 180 MINUTE))", status]).count
  end


  def voters(status=nil, include_call_retries=true, limit=300)
    voters_returned = []
    return voters_returned if !self.account.activated? || self.caller_id.blank?
    active_list_ids = VoterList.active_voter_list_ids(self.id)
    return voters_returned if active_list_ids.empty?
    voters_returned.concat(Voter.to_be_called(id, active_list_ids, status, recycle_rate))
    voters_returned.uniq
  end


  def callers_available_for_call
    RedisAvailableCaller.count(self.id)
    # CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(self.id, 1, 1)
  end


  def average(array)
  array.sum.to_f / array.size
  end


  def answers_result(from_date, to_date)
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
    0.09
  end

  def callers_status
    campaign_callers = caller_sessions.on_call
    on_hold = campaign_callers.select {|caller| (caller.on_call? && caller.available_for_call? )}
    on_call = campaign_callers.select {|caller| (caller.on_call? && !caller.available_for_call?)}
    [campaign_callers.size, on_hold.size, on_call.size]
  end

  def call_status
    wrap_up = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::SUCCESS).not_wrapped_up.size
    ringing_lines = call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    live_lines = call_attempts.between(5.minutes.ago, Time.now).with_status(CallAttempt::Status::INPROGRESS).size
    [wrap_up, ringing_lines, live_lines]
  end

  def leads_available_now
    sanitize_dials(all_voters.enabled.avialable_to_be_retried(recycle_rate).count + all_voters.scheduled.count + all_voters.by_status(CallAttempt::Status::ABANDONED).count)
  end

  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
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
    num_remaining = all_voters.by_status('not called').count
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
