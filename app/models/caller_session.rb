class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  scope :not_on_call, :conditions => {:on_call => false}
  scope :held_for_duration, lambda{|minutes| {:conditions => ["hold_time_start <= ?", minutes.ago]}}
  scope :between, lambda{|from_date, to_date| { :conditions => { :created_at => from_date..to_date } }}
  has_one :voter_in_progress, :class_name => 'Voter'
  has_one :attempt_in_progress, :class_name => 'CallAttempt'
  unloadable

  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
  
  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
     t = TwilioLib.new(account, auth)
     t.end_call("#{self.sid}")
     self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
     self.publish("caller_disconnected",{})     
   end


  def call(voter)
    voter.update_attribute(:caller_session, self)
    voter.dial_predictive
    self.publish("calling",voter.info)
  end

  def hold
    Twilio::Verb.new{|v| v.play "#{Settings.host}:#{Settings.port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end

  def preview_dial(voter)
    attempt = voter.call_attempts.create(:campaign => self.campaign, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => self)
    update_attribute('attempt_in_progress',attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    response = Twilio::Call.make(self.campaign.caller_id, voter.Phone, connect_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),
    {'StatusCallBack' => end_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),
      'IfMachine' => self.campaign.use_recordings? ? 'Continue' : 'Hangup' ,
    'Timeout' => campaign.answer_detection_timeout || "20"}
    )
    self.publish('calling_voter',voter.info)
    attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
  end

  def ask_for_campaign(attempt = 0)
    Twilio::Verb.new do |v|
      case attempt
      when 0
        v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(self.caller, :session => self, :host => Settings.host, :port => Settings.port, :attempt => attempt + 1), :method => "POST") do
          v.say "Please enter your campaign ID."
        end
      when 1, 2
        v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(self.caller , :session => self, :host => Settings.host, :port => Settings.port, :attempt => attempt + 1), :method => "POST") do
          v.say "Incorrect campaign ID. Please enter your campaign ID."
        end
      else
        v.say "That campaign ID is incorrect. Please contact your campaign administrator."
        v.hangup
      end
    end.response
  end

  def start
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => pause_caller_url(self.caller, :host => Settings.host, :port => Settings.port, :session_id => id)) do
        v.conference(self.session_key, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port), :waitMethod => 'GET')
      end
    end.response
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    response
  end

  def pause_for_results
    self.publish("waiting_for_result",{})
    Twilio::Verb.new{|v| v.say("Enter results."); v.pause("length" => 2); v.redirect(pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id))}.response
  end

  def end
  self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
  self.publish("caller_disconnected",{})
  Twilio::Verb.hangup
end

def publish(event,data)
  return unless self.campaign.use_web_ui?
  Rails.logger.debug("PUSHER APP ID ::::::::::::::::::::::::::::::::::::::  #{Pusher.app_id}////////////////////////////#{event}")
  Pusher[self.session_key].trigger(event,data)
end
end
