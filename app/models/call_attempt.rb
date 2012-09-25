require Rails.root.join("lib/twilio_lib")

class CallAttempt < ActiveRecord::Base

  include Rails.application.routes.url_helpers
  include LeadEvents
  include CallPayment
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
    not_wrapped_up = CallAttempt.not_wrapped_up.find_all_by_caller_id(caller_id)
    not_wrapped_up.each {|call_attempt| call_attempt.update_attributes(wrapup_time: Time.now)}
  end

  def connect_call
    session = voter.caller_session
    update_attributes(status: CallAttempt::Status::INPROGRESS, connecttime: Time.now, caller: session.caller, caller_session: session)
  end

  def abandon_call
    update_attributes(status: CallAttempt::Status::ABANDONED, connecttime: Time.now, wrapup_time: Time.now, call_end: Time.now)
    voter.update_attributes(:status => CallAttempt::Status::ABANDONED, call_back: false, caller_session: nil, caller_id: nil)
  end

  def connect_lead_to_caller
    begin
      voter.caller_session ||= campaign.oldest_available_caller_session
      unless voter.caller_session.nil?
        voter.caller_id = voter.caller_session.caller_id
        voter.status = CallAttempt::Status::INPROGRESS
        voter.save
        voter.caller_session.update_attributes(on_call: true, available_for_call: false)
      end
    rescue ActiveRecord::StaleObjectError
      abandon_call
    end
  end

  def caller_not_available?
    connect_lead_to_caller
    voter.caller_session.nil? || voter.caller_session.disconnected?
  end

  def caller_available?
    !caller_not_available?
  end


  def end_answered_call
    begin
      update_attributes(call_end: Time.now)
      voter.update_attributes(last_call_attempt_time:  Time.now, caller_session: nil, status: CallAttempt::Status::SUCCESS)
    rescue ActiveRecord::StaleObjectError
      voter_to_update = Voter.find(voter.id)
      voter_to_update.update_attributes(last_call_attempt_time:  Time.now, caller_session: nil)
    end
  end

  def process_answered_by_machine
    update_attributes(connecttime: Time.now, call_end:  Time.now, status:  campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP, wrapup_time: Time.now)
    voter.update_attributes(status: campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP, caller_session: nil)
  end

  def end_answered_by_machine
    update_attributes(wrapup_time: Time.now, call_end: Time.now)
    voter.update_attributes(last_call_attempt_time:  Time.now, call_back: false)
  end


  def end_unanswered_call(call_status)
    update_attributes(status:  CallAttempt::Status::MAP[call_status], wrapup_time: Time.now, call_end: Time.now)
    begin
      voter.update_attributes(status:  CallAttempt::Status::MAP[call_status], last_call_attempt_time:  Time.now, call_back: false)
    rescue ActiveRecord::StaleObjectError
      voter_to_update = Voter.find(voter.id)
      voter_to_update.update_attributes(status:  CallAttempt::Status::MAP[call_status], last_call_attempt_time:  Time.now, call_back: false)
    end
  end

  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    Resque.enqueue(EndRunningCallJob, self.sid)
  end

  def not_wrapped_up?
    wrapup_time.nil?
  end
    
  def disconnect_call    
    update_attributes(status: CallAttempt::Status::SUCCESS, recording_duration: call.recording_duration, recording_url: call.recording_url, call_end: Time.now)
    voter.update_attributes(last_call_attempt_time:  Time.now, caller_session: nil, status: CallAttempt::Status::SUCCESS)
  end

  def schedule_for_later(date)
    scheduled_date = DateTime.strptime(date, "%m/%d/%Y %H:%M").to_time
    update_attributes(:scheduled_date => scheduled_date, :status => Status::SCHEDULED)
    voter.update_attributes(:scheduled_date => scheduled_date, :status => Status::SCHEDULED, :call_back => true)
  end

  def wrapup_now
    update_attribute(:wrapup_time, Time.now)
  end

  def self.time_on_call(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)').to_i
  end

  def self.time_in_wrapup(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)').to_i
  end

  def self.lead_time(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
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
    DIALING = "Dialing"

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED}
    ALL = MAP.values
    RETRY = [NOANSWER, BUSY, FAILED]
    ANSWERED =  [INPROGRESS, SUCCESS]
  end

  def redirect_caller(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    unless caller_session.nil?
      Resque.enqueue(RedirectCallerJob, caller_session.id)
    end    
  end
end
