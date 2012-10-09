require 'new_relic/agent/method_tracer'
require Rails.root.join("lib/twilio_lib")
require Rails.root.join("lib/redis_connection")

class CallAttempt < ActiveRecord::Base
  include ::NewRelic::Agent::MethodTracer
  include Rails.application.routes.url_helpers
  include CallPayment
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
  scope :debit_not_processed, where(debited: "0").where('call_end is not null')



  def report_recording_url
    "#{self.recording_url.gsub("api.twilio.com", "recordings.impactdialing.com")}.mp3" if recording_url
  end


  def duration
    return nil unless connecttime
    ((call_end || Time.now) - connecttime).to_i
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
    self.wrapup_time = time
  end
    
  def end_answered_by_machine(connect_time, end_time)
    self.connecttime = connect_time
    self.wrapup_time = end_time
    self.call_end = end_time
    self.status = campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
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
    if caller_type == CallerSession::CallerType::PHONE
      self.voter_response_processed = true
    end
  end
  
  def connect_caller_to_lead
    caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign.id)
    unless caller_session_id.nil?
      caller_session = CallerSession.find(caller_session_id)
      begin
        caller_session.update_attributes(attempt_in_progress: self, voter_in_progress: self.voter, available_for_call: false)
      rescue ActiveRecord::StaleObjectError 
        RedisOnHoldCaller.add_to_end(campaign.id, caller_session_id)
      end        
    end
  end
  
  def connect_call
    update_attributes(connecttime: Time.now)
  end
  
  def not_wrapped_up?
    wrapup_time.nil?
  end



  def self.time_on_call(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)').to_i
  end

  def self.time_in_wrapup(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)').to_i
  end

  def self.lead_time(caller, campaign, from, to)
    result = CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).
      without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED])
    result = result.from("call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)") if campaign
    result.sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end

  def call_not_connected?
    connecttime.nil? || call_end.nil?
  end

  def call_time
  ((call_end - connecttime)/60).ceil
  end  
  
  
  module Status
    VOICEMAIL = 'Message delivered'
    SUCCESS = 'Call completed with success.'
    INPROGRESS = 'Call in progress'
    NOANSWER = 'No answer'
    ABANDONED = "Call abandoned"
    BUSY = "No answer busy signal"
    FAILED = "Call failed"
    HANGUP = "Hangup or answering machine"
    READY = "Call ready to dial"
    CANCELLED = "Call cancelled"
    SCHEDULED = 'Scheduled for later'
    RINGING = "Ringing"

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED}
    ALL = MAP.values
    RETRY = [NOANSWER, BUSY, FAILED]
    ANSWERED =  [INPROGRESS, SUCCESS]
  end

  def redirect_caller
    unless caller_session.nil?
      enqueue_call_flow(RedirectCallerJob, [caller_session.id])
    end    
  end
  
  def end_caller_session
    caller_session.run('stop_calling')
  end

  #NewRelic custom metrics
  add_method_tracer :connect_lead_to_caller,      'Custom/CallAttempt/connect_lead_to_caller'
  add_method_tracer :connect_call,                'Custom/CallAttempt/connect_call'
  add_method_tracer :abandon_call,                'Custom/CallAttempt/abandon_call'
  add_method_tracer :caller_not_available?,       'Custom/CallAttempt/caller_not_available?'
  add_method_tracer :end_answered_call,           'Custom/CallAttempt/end_answered_call'
  add_method_tracer :process_answered_by_machine, 'Custom/CallAttempt/process_answered_by_machine'
  add_method_tracer :end_answered_by_machine,     'Custom/CallAttempt/end_answered_by_machine'
  add_method_tracer :end_unanswered_call,         'Custom/CallAttempt/end_unanswered_call'
  add_method_tracer :disconnect_call,             'Custom/CallAttempt/disconnect_call'
  add_method_tracer :schedule_for_later,          'Custom/CallAttempt/schedule_for_later'
  add_method_tracer :wrapup_now,                  'Custom/CallAttempt/wrapup_now'
end