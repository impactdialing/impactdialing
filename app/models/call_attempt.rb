class CallAttempt < ActiveRecord::Base
  belongs_to :voter, :class_name => "Voter", :foreign_key => "voter_id"
  def duration
    if self.call_end!=nil &&self.call_start!=nil
      (self.call_end  - self.call_start).to_i
    else
      nil
    end
  end
  
  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
end
