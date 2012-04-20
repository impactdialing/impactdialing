require Rails.root.join("lib/twilio_lib")

class CallAttempt < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  belongs_to :caller_session
  has_many :call_responses
  has_one :transfer_attempt
  belongs_to :call

  scope :dial_in_progress, where('call_end is null')
  scope :not_wrapped_up, where('wrapup_time is null')
  scope :for_campaign, lambda { |campaign| {:conditions => ["campaign_id = ?", campaign.id]}  unless campaign.nil?}
  scope :for_caller, lambda { |caller| {:conditions => ["caller_id = ?", caller.id]}  unless caller.nil?}
  
  scope :for_status, lambda { |status| {:conditions => ["call_attempts.status = ?", status]} }
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :without_status, lambda { |statuses| {:conditions => ['status not in (?)', statuses]} }
  scope :with_status, lambda { |statuses| {:conditions => ['status in (?)', statuses]} }
  
  module Type
    PREVIEW = "PreviewCallAttempt"
    PREDICTIVE = "PredictiveCallAttempt"
    PROGRESSIVE = "ProgressiveCallAttempt"
    ROBO = "RoboCallAttempt"
  end
  

  def report_recording_url
    "#{self.recording_url.gsub("api.twilio.com", "recordings.impactdialing.com")}.mp3" if recording_url
  end

  def ring_time
    if self.answertime!=nil && self.created_at!=nil
      (self.answertime - self.created_at).to_i
    else
      nil
    end
  end

  def duration
    return nil unless call_start
    ((call_end || Time.now) - call_start).to_i
  end
    

  def duration_wrapped_up
    ((wrapup_time || Time.now) - (self.call_start || Time.now)).to_i
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

  def next_recording(current_recording = nil, call_response = nil)
    return campaign.script.robo_recordings.first.twilio_xml(self) unless current_recording
    if call_response
      (return current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup) if call_response.recording_response
      return current_recording.hangup if call_response.times_attempted > 2
      return current_recording.twilio_xml(self) if call_response && !call_response.recording_response
    end
    current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup
  end
  
  
  def call_answered_by_machine
    update_attribute(:connecttime, Time.now)
    process_call_answered_by_machine
    update_attribute(:wrapup_time, Time.now)                    
    campaign.use_recordings? ? play_recorded_message : hangup    
  end
  
  def connect_call
    update_attribute(:connecttime, Time.now)
    connect_to_caller      
  end
    
  def connect_to_caller    
    update_attribute(:status, CallAttempt::Status::INPROGRESS)
    voter.update_attribute(:caller_id, caller_session.caller_id)
    begin
      caller_session.update_attributes(:on_call => true, :available_for_call => false)
      # conference(caller_session)
    rescue ActiveRecord::StaleObjectError
      abandon_call
    end
  end
  
  def abandon_call
    update_attributes(status: CallAttempt::Status::ABANDONED, wrapup_time: Time.now)
    voter.update_attributes(:status => CallAttempt::Status::ABANDONED, call_back: false)
    Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})    
  end
  
  
  
  def success
    if [CallAttempt::Status::HANGUP, CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED].include? call_attempt.status
      voter.update_attributes(:last_call_attempt_time => Time.now)
      update_attributes(:call_end => Time.now)
    else
      voter.update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]], :last_call_attempt_time => Time.now)
      update_attributes(:status => CallAttempt::Status::MAP[params[:CallStatus]])
    end
    call_attempt.debit  
    response = case params[:CallStatus] #using the 2010 api
                 when "no-answer", "busy", "failed"
                   call_attempt.fail
                 else
                   call_attempt.hangup
               end
    render :xml => response
  end
  

  def process_call_answered_by_machine
    voter.update_attributes(:status => CallAttempt::Status::HANGUP)
    update_attribute(:status, CallAttempt::Status::HANGUP)    
  end
  
  def caller_not_available?  
    caller_session = voter.caller_session || campaign.oldest_available_caller_session
    caller_session.nil? || caller_session.disconnected? || !caller_session.available_for_call?
  end
  
  def caller_available?  
    !caller_not_available?
  end
  

  def leave_voicemail
    update_attributes(:status => CallAttempt::Status::VOICEMAIL)
    voter.update_attributes(:status => CallAttempt::Status::VOICEMAIL)
    self.campaign.voicemail_script.robo_recordings.first.play_message(self)
  end

  def play_recorded_message
    update_attributes(:call_end => Time.now, :status => campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP)
    voter.update_attributes(:status => campaign.use_recordings? ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP)
    return hangup unless campaign.use_recordings?
    Twilio::TwiML::Response.new do |r|
      r.Play campaign.recording.file.url
      r.Hangup
    end.text
  end

  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    t = TwilioLib.new(account, auth)
    t.end_call("#{self.sid}")
  end


  def conference(session)
    self.update_attributes(:caller => session.caller, :call_start => Time.now, :caller_session => session)
    session.publish('voter_connected', {:attempt_id => self.id, :voter => self.voter.info})
    Moderator.publish_event(campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, :caller_id => session.caller.id})
    voter.conference(session)
    Twilio::TwiML::Response.new do |r|
      r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(self, :host => Settings.host), :record=>self.campaign.account.record_calls do |d|
        d.Conference session.session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
      end
    end.text
  end

  def wait(time)
    Twilio::TwiML::Response.new do |r|
      r.Pause :length => time
      r.Redirect "#{connect_call_attempt_path(:id => self.id)}"
    end.text
  end
  
  def disconnected(params={})
    update_attributes(:status => CallAttempt::Status::SUCCESS, :call_end => Time.now, :recording_duration=>params[:RecordingDuration], :recording_url=>params[:RecordingUrl])
    voter.update_attribute(:status, CallAttempt::Status::SUCCESS)
    Pusher[caller_session.session_key].trigger('voter_disconnected', {:attempt_id => self.id, :voter => self.voter.info})
    Moderator.publish_event(campaign, 'voter_disconnected', {:caller_session_id => caller_session.id,:campaign_id => campaign.id, :caller_id => caller_session.caller.id, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    hangup
  end
  

  def disconnect(params={})
    update_attributes(:status => CallAttempt::Status::SUCCESS, :call_end => Time.now, :recording_duration=>params[:RecordingDuration], :recording_url=>params[:RecordingUrl])
    voter.update_attribute(:status, CallAttempt::Status::SUCCESS)
    Pusher[caller_session.session_key].trigger('voter_disconnected', {:attempt_id => self.id, :voter => self.voter.info})
    Moderator.publish_event(campaign, 'voter_disconnected', {:caller_session_id => caller_session.id,:campaign_id => campaign.id, :caller_id => caller_session.caller.id, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    hangup
  end

  def fail
    voter.update_attributes(:call_back => false)
    update_attributes(wrapup_time: Time.now)
    Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    if caller_session && (campaign.type == Campaign::Type::PREVIEW || campaign.type == Campaign::Type::PROGRESSIVE)
      caller_session.update_attribute(:voter_in_progress, nil)      
      if caller_session.caller.is_phones_only?
        caller_session.redirect_to_phones_only_start
      else  
        next_voter = self.campaign.next_voter_in_dial_queue(voter.id) 
        caller_session.publish('voter_push',next_voter.nil? ? {} : next_voter.info)         
        caller_session.start
      end  
    else
      hangup                        
    end  
  end

  def hangup
    Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end

  def schedule_for_later(scheduled_date)
    update_attributes(:scheduled_date => scheduled_date, :status => Status::SCHEDULED)
    voter.update_attributes(:scheduled_date => scheduled_date, :status => Status::SCHEDULED, :call_back => true)
  end

  def wrapup_now
    update_attributes(:wrapup_time => Time.now)
  end
  
  def capture_answer_as_no_response
    return if (connecttime == nil)
    voter.campaign.script.questions.not_answered_by(voter).try(:each) do |question|
      possible_response = question.possible_responses.find_by_value("[No response]") || question.possible_responses.create(:value => "[No response]")
      possible_response.answers.create(:question => question, :voter => voter, :campaign => campaign, :caller => caller)
    end
  end
  
  def capture_answer_as_no_response_for_robo
    campaign.script.robo_recordings.not_responded_by(voter).try(:each) do |robo_recording|
      recording_response = robo_recording.recording_responses.find_by_response("[No response]") || robo_recording.recording_responses.create(:response => "[No response]", :keypad =>10)
      recording_response.call_responses.create(:robo_recording => robo_recording, :call_attempt => self, :campaign => campaign)
    end
  end
  
  def self.time_on_call(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,connecttime,call_end)')
  end
  
  def self.time_in_wrapup(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('TIMESTAMPDIFF(SECOND ,call_end,wrapup_time)')
  end
  
  def self.lead_time(caller, campaign, from, to)
    CallAttempt.for_campaign(campaign).for_caller(caller).between(from, to).without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
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

  def debit
    return false if self.call_start.nil? || self.call_end.nil?
    call_time = ((self.call_end - self.call_start)/60).ceil
    Payment.debit(call_time, self)
  end

end
