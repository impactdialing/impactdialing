require Rails.root.join("lib/twilio_lib")

class Campaign < ActiveRecord::Base
  include Deletable
  cache_records :store => :shared, :key => "cam", :request_cache => true

  has_many :caller_sessions
  has_many :voter_lists, :conditions => {:active => true}
  has_many :all_voters, :class_name => 'Voter'
  has_many :call_attempts
  has_many :transfer_attempts
  has_many :callers
  has_one :simulated_values
  has_many :answers
  has_many :call_responses
  belongs_to :script
  belongs_to :voicemail_script, :class_name => 'Script', :foreign_key => 'voicemail_script_id'
  belongs_to :account
  belongs_to :recording
  has_many :downloaded_reports

  delegate :questions_and_responses, :to => :script

  scope :robo, lambda { where(:type => 'robo') }
  scope :manual, :conditions => [ 'campaigns.type != "robo"' ]
  scope :for_account, lambda { |account| {:conditions => ["account_id = ?", account.id]} }
  scope :with_running_caller_sessions, {
      :select => "distinct campaigns.*",
      :joins => "inner join caller_sessions on (caller_sessions.campaign_id = campaigns.id)",
      :conditions => {"caller_sessions.on_call" => true}
  }
  scope :using_web_ui, :conditions => {:use_web_ui => true}
  scope :for_caller, lambda { |caller| {:include => [:caller_sessions], :conditions => {"caller_sessions.caller_id" => caller.id}}}

  before_create :create_uniq_pin

  validates :name, :presence => true
  validates :caller_id, :presence => true, :unless => :new_campaign
  validates :caller_id, :numericality => {:on => :update}, :length => {:on => :update, :minimum => 10, :maximum => 10}, :unless => Proc.new{|campaign| campaign.caller_id && campaign.caller_id.start_with?('+')}
  validate :set_caller_id_error_msg
  validate :campaign_type_changed
  cattr_reader :per_page
  @@per_page = 25

  before_validation :set_untitled_name
  before_save :set_untitled_name
  before_validation :sanitize_caller_id

  module Type
    PREVIEW = "Preview"
    PREDICTIVE = "Predictive"
    PROGRESSIVE = "Progressive"
    ROBO = "Robo"
  end

  def new_campaign
    new_record?
  end

  def set_caller_id_error_msg
      if errors[:caller_id].any?
        errors.add(:base, 'Your Caller ID must be a 10-digit North American phone number or begin with "+" and the country code.')
        errors[:caller_id].clear
      end
    end

  def campaign_type_changed
    if type_changed? && callers_log_in?
      errors.add(:base, 'You cannot change dialing modes while callers are logged in.')
    end
  end


  def is_preview_or_progressive
    type == Type::PREVIEW || type == Type::PROGRESSIVE
  end

  def set_untitled_name
    self.name = "Untitled #{account.campaigns.count + 1}" if self.name.blank?
  end

  def sanitize_caller_id
    self.caller_id = Voter.sanitize_phone(self.caller_id)
  end

  def create_uniq_pin
    pin = nil

    loop do
      pin = rand.to_s[2..6]
      break unless Campaign.find_by_campaign_id(pin)
    end
    self.campaign_id = pin
  end

  def set_answering_machine_detect
    self.answering_machine_detect = self.use_recordings = self.robo? && !self.voicemail_script.nil?
  end

  def disable_voter_list
    voter_lists.each do |voter_list|
      voter_list.enabled = false
      voter_list.save
    end
  end


  def time_period_exceeded?
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
    unless script.nil?      
      answer_count = Answer.select("possible_response_id").where("campaign_id = ?", self.id).within(from_date, to_date).group("possible_response_id").count
      total_answers = Answer.where("campaign_id = ?",self.id).within(from_date, to_date).group("question_id").count
      script.questions.each do |question|        
        result[question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(answer_count, total_answers) }
        result[question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.find_by_value("[No response]").present?
      end
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


end
