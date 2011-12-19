require Rails.root.join("lib/twilio_lib")

class CallAttempt < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  belongs_to :caller_session
  has_many :call_responses

  scope :dial_in_progress, where('call_end is null')
  scope :not_wrapped_up, where('wrapup_time is null')
  scope :for_campaign, lambda { |campaign| {:conditions => ["campaign_id = ?", campaign.id]} }
  scope :for_status, lambda { |status| {:conditions => ["call_attempts.status = ?", status]} }
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :without_status, lambda { |statuses| {:conditions => ['status not in (?)', statuses]} }
  scope :with_status, lambda { |statuses| {:conditions => ['status in (?)', statuses]} }


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
    ((call_end || Time.now) - self.call_start).to_i
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

  def next_recording(current_recording = nil, call_response = nil)
    return campaign.script.robo_recordings.first.twilio_xml(self) unless current_recording
    if call_response
      (return current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup) if call_response.recording_response
      return current_recording.hangup if call_response.times_attempted > 2
      return current_recording.twilio_xml(self) if call_response && !call_response.recording_response
    end
    current_recording.next ? current_recording.next.twilio_xml(self) : current_recording.hangup
  end

  def connect_to_caller(caller_session=nil)
    caller_session ||= campaign.oldest_available_caller_session
    if caller_session.nil? || caller_session.disconnected? || !caller_session.available_for_call
      update_attributes(status: CallAttempt::Status::ABANDONED, wrapup_time: Time.now)
      voter.update_attributes(:status => CallAttempt::Status::ABANDONED, call_back: false)
      caller_session.update_attribute(:voter_in_progress, nil) unless caller_session.nil?
      Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.dial_in_progress.length, :voters_remaining => campaign.voters_count("not called", false).length})
      hangup
    else
      update_attributes(:status => CallAttempt::Status::INPROGRESS)
      voter.update_attributes(:status => CallAttempt::Status::INPROGRESS)
      caller_session.update_attributes(:on_call => true, :available_for_call => false)
      conference(caller_session)
    end
  end

  def play_recorded_message
    update_attributes(:status => CallAttempt::Status::VOICEMAIL, :call_end => Time.now)
    voter.update_attributes(:status => CallAttempt::Status::VOICEMAIL)
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
    Moderator.publish_event(campaign, 'voter_connected', {:campaign_id => campaign.id, :caller_id => session.caller.id, :dials_in_progress => campaign.call_attempts.dial_in_progress.length})
    Rails.logger.debug("Moderator published event")
    voter.conference(session)
    Rails.logger.debug("Voter conference")
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

  def disconnect(params={})
    update_attributes(:status => CallAttempt::Status::SUCCESS, :call_end => Time.now, :recording_duration=>params[:RecordingDuration], :recording_url=>params[:RecordingUrl])
    voter.update_attribute(:status, CallAttempt::Status::SUCCESS)
    Pusher[caller_session.session_key].trigger('voter_disconnected', {:attempt_id => self.id, :voter => self.voter.info})
    Moderator.publish_event(campaign, 'voter_disconnected', {:campaign_id => campaign.id, :caller_id => caller_session.caller.id,
                                                             :dials_in_progress => campaign.call_attempts.dial_in_progress.length, :voters_remaining => campaign.voters_count("not called", false).length})
    hangup
  end

  def fail
    next_voter = self.campaign.next_voter_in_dial_queue(voter.id)
    voter.update_attributes(:call_back => false)
    update_attributes(wrapup_time: Time.now)
    if caller_session && (campaign.predictive_type == Campaign::Type::PREVIEW || campaign.predictive_type == Campaign::Type::PROGRESSIVE)
      caller_session.publish('voter_push', next_voter.nil? ? {} : next_voter.info)
      caller_session.update_attribute(:voter_in_progress, nil)
      caller_session.start
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

  module Status
    VOICEMAIL = "Message delivered"
    SUCCESS = "Call completed with success."
    INPROGRESS = "Call in progress"
    NOANSWER = "No answer"
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
  end

end
