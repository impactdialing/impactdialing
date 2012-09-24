require Rails.root.join("lib/twilio_lib")

class Campaign < ActiveRecord::Base
  include Deletable

  attr_accessible :type, :name, :caller_id, :script_id, :acceptable_abandon_rate, :time_zone, :start_time, :end_time, :recycle_rate, :answering_machine_detect, :voter_lists_attributes, :use_recordings, :recording_id

  has_many :caller_sessions
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
  scope :for_caller, lambda { |caller| {:include => [:caller_sessions], :conditions => {"caller_sessions.caller_id" => caller.id}}}

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
  validate :campaign_type_changed
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

  def oldest_available_caller_session
    caller_sessions.available.find(:first, :order => "updated_at ASC")
  end

  def callers_log_in?
    caller_sessions.on_call.length > 0
  end
  
  def as_time_zone
    time_zone.nil? ? nil : ActiveSupport::TimeZone.new(time_zone)
  end
  
  def first_call_attempt_time
    call_attempts.first.try(:created_at) 
  end
  
  def last_call_attempt_time
    call_attempts.last.try(:created_at)
  end  


  def voters_called
    Voter.find_all_by_campaign_id(self.id, :select=>"id", :conditions=>"status <> 'not called'")
  end


  def voters_count(status=nil, include_call_retries=true)
    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(self.id, 1, 1)
    return [] if active_lists.length==0
    active_list_ids = active_lists.collect { |x| x.id }
    Voter.count(1, :select=>"id", :conditions=>"active = 1 and voter_list_id in (#{active_list_ids.join(",")})  and (status='#{status}' OR (call_back=1 and last_call_attempt_time < (Now() - INTERVAL 180 MINUTE)) )")
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
    CallerSession.find_all_by_campaign_id_and_on_call_and_available_for_call(self.id, 1, 1)
  end


  def average(array)
  array.sum.to_f / array.size
  end


  def answers_result(from_date, to_date)
    result = Hash.new
    question_ids = Answer.all(:select=>"distinct question_id", :conditions=>"campaign_id = #{self.id}")
    answer_count = Answer.select("possible_response_id").where("campaign_id = ?", self.id).within(from_date, to_date).group("possible_response_id").count
    total_answers = Answer.from("answers use index (index_answers_count_question)").where("campaign_id = ?",self.id).within(from_date, to_date).group("question_id").count
    questions = Question.where("id in (?)",question_ids.collect{|q| q.question_id})
    questions.each do |question|
      result[question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(answer_count, total_answers) }
      result[question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.find_by_value("[No response]").present?
    end
    result
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
    transfer_attempts.between(from_date, to_date).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def voicemail_time(from_date, to_date)
    call_attempts.between(from_date, to_date).with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def abandoned_calls_time(from_date, to_date)
    call_attempts.between(from_date, to_date).with_status([CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def cost_per_minute
    0.09
  end
end
