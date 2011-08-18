class CallerSession < ActiveRecord::Base
  belongs_to :caller
  belongs_to :campaign
  named_scope :on_call, :conditions => {:on_call => true}
  named_scope :available, :conditions => {:available_for_call => true, :on_call => true}
  has_one :voter_in_progress, :class_name => 'Voter'
  unloadable

  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end

    #  def end_call(account,auth,appurl)
  def end_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH, appurl=APP_URL)
    t = TwilioLib.new(account, auth)
    a=t.call("POST", "Calls/#{self.sid}", {'CurrentUrl'=>"#{appurl}/callin/callerEndCall?session=#{self.id}"})
    if a.index("RestException")
      self.on_call=false
      self.save
    end
  end

  def call(voter)
    voter.update_attribute(:caller_session, self)
    voter.dial_predictive
  end

end
