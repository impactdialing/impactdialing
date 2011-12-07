require Rails.root.join("lib/twilio_lib")

class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  scope :dial_in_progress, :conditions => {:available_for_call => false, :on_call => true}
  scope :not_on_call, :conditions => {:on_call => false}
  scope :held_for_duration, lambda { |minutes| {:conditions => ["hold_time_start <= ?", minutes.ago]} }
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  has_one :voter_in_progress, :class_name => 'Voter'
  has_one :attempt_in_progress, :class_name => 'CallAttempt'
  has_one :moderator
  unloadable

  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end

  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    t = ::TwilioLib.new(account, auth)
    t.end_call("#{self.sid}")
    self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    Moderator.publish_event(caller, "caller_disconnected",{:caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
      :no_of_callers_logged_in => campaign.caller_sessions.on_call.length})
    self.publish("caller_disconnected", {source: "end_running_call"})
  end


  def call(voter)
    voter.update_attribute(:caller_session, self)
    voter.dial_predictive
    self.publish("calling", voter.info)
  end

  def hold
    Twilio::Verb.new { |v| v.play "#{Settings.host}:#{Settings.port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end

  def preview_dial(voter)
    attempt = voter.call_attempts.create(:campaign => self.campaign, :dialer_mode => campaign.predictive_type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = { 'StatusCallback' => end_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),'Timeout' => campaign.answering_machine_detect ? "30" : "15"}
    params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect        
    response = Twilio::Call.make(self.campaign.caller_id, voter.Phone, connect_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),params)
    self.publish('calling_voter', voter.info)
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
          v.gather(:numDigits => 5, :timeout => 10, :action => assign_campaign_caller_url(self.caller, :session => self, :host => Settings.host, :port => Settings.port, :attempt => attempt + 1), :method => "POST") do
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
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
      end
    end.response
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    publish('caller_connected_dialer', {}) if campaign.predictive_type != Campaign::Type::PREVIEW && campaign.predictive_type != Campaign::Type::PROGRESSIVE
    response
  end
  
  def join_conference(mute_type, call_sid, monitor_session)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "#{APP_URL}/callin/hold",:waitMethod =>"GET",:muted => mute_type)
      end
    end.response
    moderator = Moderator.find_by_session(monitor_session)
    moderator.update_attributes(:caller_session_id => self.id, :call_sid => call_sid)
    response
  end

  def pause_for_results(attempt = 0)
    attempt = attempt.to_i || 0
    self.publish("waiting_for_result", {}) if attempt == 0
    Twilio::Verb.new { |v| v.say("Please enter your call results")  if (attempt % 5 == 0); v.pause("length" => 2); v.redirect(pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id, :attempt=>attempt+1)) }.response
  end


  def end
    self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    Moderator.publish_event(caller, "caller_disconnected",{:caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
            :no_of_callers_logged_in => campaign.caller_sessions.on_call.length})
    self.publish("caller_disconnected", {source: "end_call"})
    Twilio::Verb.hangup
  end
  
  def disconnected?
    !available_for_call && !on_call
  end
  

  def publish(event, data)
    return unless self.campaign.use_web_ui?
    Rails.logger.debug("PUSHER APP ID ::::::::::::::::::::::::::::::::::::::  #{Pusher.app_id}////////////////////////////#{event}")
    Pusher[self.session_key].trigger(event, data.merge!(:dialer => self.campaign.predictive_type))
  end
end
