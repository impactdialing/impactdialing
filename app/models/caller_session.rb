class CallerSession < ActiveRecord::Base
  include ActionController::UrlWriter
  belongs_to :caller
  belongs_to :campaign
  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
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
    self.publish("calling",voter.info)
  end

  def preview_dial(voter)
    attempt = voter.call_attempts.create(:campaign => self.campaign, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => self)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    response = Twilio::Call.make(
        self.campaign.caller_id,
        voter.Phone,
        connect_call_attempt_url(attempt, :host => Settings.host, :port =>Settings.port),
        'IfMachine' => self.campaign.use_recordings? ? 'Continue' : 'Hangup' ,
        'Timeout' => campaign.answer_detection_timeout || "20"
    )
    self.publish('calling_voter',voter.info)
    attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
  end

  def ask_for_campaign(attempt = 0)
    Twilio::Verb.new do |v|
      case attempt
        when 0
          v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(self.caller, :session => self, :host => Settings.host, :attempt => attempt + 1), :method => "POST") do
            v.say "Please enter your campaign id."
          end
        when 1, 2
          v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(self.caller , :session => self, :host => Settings.host, :attempt => attempt + 1), :method => "POST") do
            v.say "Incorrect campaign Id. Please enter your campaign Id."
          end
        else
          v.say "Incorrect campaign Id."
          v.hangup
      end
    end.response
  end

  def start
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => end_session_caller_url(self.caller, :host => Settings.host, :session => self.id, :campaign => self.campaign.id)) do
        v.conference(self.session_key, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => "GET")
      end
    end.response
    update_attributes(:on_call => true, :available_for_call => true)
    first_voter = self.campaign.all_voters.to_be_dialed.first
    self.publish("caller_connected", first_voter ? first_voter.info : {}) if self.campaign.predictive_type == Campaign::Type::PREVIEW
    response
  end

  def end
    self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    self.publish("caller_disconnected",{})
  end

  def publish(event,data)
    return unless self.campaign.use_web_ui?
    Pusher[self.session_key].trigger(event,data)
  end

  def end_call(*args)
    #publish(*args)
  end
end
