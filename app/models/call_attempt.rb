class CallAttempt < ActiveRecord::Base
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  has_many :call_responses

  named_scope :for_campaign, lambda{|campaign| {:conditions => ["campaign_id = ?", campaign.id] }}
  named_scope :for_status, lambda{|status| {:conditions => ["call_attempts.status = ?", status] }}
  named_scope :between, lambda{|from_date, to_date| { :conditions => { :created_at => from_date..to_date } }}
  named_scope :without_status, lambda{|statuses| { :conditions => ['status not in (?)', statuses] }}
  named_scope :with_status, lambda{|statuses| { :conditions => ['status in (?)', statuses] }}

  def ring_time
    if self.answertime!=nil && self.created_at!=nil
      (self.answertime  - self.created_at).to_i
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

    MAP = {'in-progress' => INPROGRESS, 'completed' => SUCCESS, 'busy' => BUSY, 'failed' => FAILED, 'no-answer' => NOANSWER, 'canceled' => CANCELLED }
    ALL = MAP.values
  end

end
