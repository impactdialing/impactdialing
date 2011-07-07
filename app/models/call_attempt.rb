class CallAttempt < ActiveRecord::Base
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller
  has_many :call_responses

  named_scope :for_campaign, lambda{|campaign| {:conditions => ["campaign_id = ?", campaign.id] }}
  named_scope :for_status, lambda{|status| {:conditions => ["status = ?", status] }}


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
    self.tDuration/60.ceil
  end

  def client
    campaign.client
  end

  module Status
    VOICEMAIL = "Message delivered"
    SUCCESS = "Call completed with success."
    INPROGRESS = "Call in progress"
  end
end
