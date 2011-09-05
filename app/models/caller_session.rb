class CallerSession < ActiveRecord::Base
  include ActionController::UrlWriter
  belongs_to :caller
  belongs_to :campaign
  scope :on_call, :conditions => { :on_call => true }
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  has_one :voter_in_progress, :class_name => 'Voter'
  unloadable

  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end

  def ask_for_campaign(attempt)
    Twilio::Verb.new do |v|
      v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(caller, :host => Settings.host), :method => "POST") do
          v.say "Please enter your campaign pin."
        end
    end.response

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
