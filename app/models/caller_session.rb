class CallerSession < ActiveRecord::Base
  belongs_to :caller, :class_name => "Caller", :foreign_key => "caller_id"
  belongs_to :campaign
  unloadable
  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
end
