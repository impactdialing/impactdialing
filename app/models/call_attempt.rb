class CallAttempt < ActiveRecord::Base
  belongs_to :voter
  belongs_to :campaign
  belongs_to :caller

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
    if self.call_end!=nil && self.call_start!=nil
      (self.call_end  - self.call_start).to_i
    elsif self.call_start!=nil && self.call_end==nil
      (Time.now  - self.call_start).to_i
    else
      nil
    end
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
