class CallerSession < ActiveRecord::Base
  belongs_to :caller, :class_name => "Caller", :foreign_key => "caller_id"
  belongs_to :campaign
  unloadable
  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
  #  def end_call(account,auth,appurl)
   def end_call(account=TWILIO_ACCOUNT,auth=TWILIO_AUTH,appurl=APP_URL)
      t = Twilio.new(account,auth)
      a=t.call("POST", "Calls/#{self.sid}", {'CurrentUrl'=>"#{appurl}/callin/callerEndCall?session=#{self.id}"})
      if a.index("RestException")
        self.on_call=false
        self.save
      end
  end

end
