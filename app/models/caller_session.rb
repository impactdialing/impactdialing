require Rails.root.join("lib/twilio_lib")

class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  scope :not_on_call, :conditions => {:on_call => false}
  scope :connected_to_voter, where('voter_in_progress is not null')
  scope :held_for_duration, lambda { |minutes| {:conditions => ["hold_time_start <= ?", minutes.ago]} }
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :on_campaign, lambda{|campaign| where("campaign_id = #{campaign.id}")}
  has_one :voter_in_progress, :class_name => 'Voter'
  has_one :attempt_in_progress, :class_name => 'CallAttempt'
  has_one :moderator
  has_many :transfer_attempts
  unloadable

  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end

  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)
    t = ::TwilioLib.new(account, auth)
    t.end_call("#{self.sid}")
    self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
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
    params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => end_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),'Timeout' => campaign.answering_machine_detect ? "30" : "15"}
    params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect        
    response = Twilio::Call.make(self.campaign.caller_id, voter.Phone, connect_call_attempt_url(attempt, :host => Settings.host, :port => Settings.port),params)
    
    if response["TwilioResponse"]["RestException"]
      Rails.logger.info "Exception when attempted to call #{voter.Phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
      attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
      voter.update_attributes(status: CallAttempt::Status::FAILED)
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil,:voter_in_progress => nil)
      if caller.is_phones_only?
        redirect_to_phones_only_start
      else
        next_voter = campaign.next_voter_in_dial_queue(voter.id)
        publish('call_could_not_connect',next_voter.nil? ? {} : next_voter.info)
      end
      return
    end    
    self.publish('calling_voter', voter.info)
    Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id,:dials_in_progress => campaign.call_attempts.dial_in_progress.size})
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
    wrapup
    unless endtime.nil?
      return Twilio::Verb.hangup
    end
    
    if caller_reassigned_to_another_campaign?
      caller.is_phones_only? ? (return reassign_caller_session_to_campaign) : reassign_caller_session_to_campaign
    end
    return time_exceed_hangup if campaign.time_period_exceed?
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => caller_response_path) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
      end
    end.response
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    if campaign.predictive_type == Campaign::Type::PREVIEW || campaign.predictive_type == Campaign::Type::PROGRESSIVE
      publish('conference_started', {}) 
    else
      publish('caller_connected_dialer', {})
    end
    response
  end
  
  def phones_only_start
    unless endtime.nil?
      return Twilio::Verb.hangup
    end
    
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true, :action => gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)) do
        v.conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
      end
    end.response
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    response
  end
  
  def ask_caller_to_choose_voter(voter = nil, caller_choice = nil)
    return reassign_caller_session_to_campaign if caller_reassigned_to_another_campaign?
    if campaign.time_period_exceed?
      time_exceed_hangup 
    else
      voter ||= campaign.next_voter_in_dial_queue
      if voter.present?
        campaign.predictive_type == Campaign::Type::PREVIEW ? say_voter_name_ask_caller_to_choose_voter(voter, caller_choice) : say_voter_name_and_call(voter)
      else
        response = Twilio::Verb.new { |v| v.say I18n.t(:campaign_has_no_more_voters) }.response
      end
    end
  end
  
  def redirect_to_phones_only_start
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, phones_only_caller_index_url(:host => Settings.host, :port => Settings.port, session_id: id, :campaign_reassigned => caller_reassigned_to_another_campaign?))
  end

  def join_conference(mute_type, call_sid, monitor_session)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "#{APP_URL}/callin/hold", :waitMethod =>"GET", :muted => mute_type)
      end
    end.response
    moderator = Moderator.find_by_session(monitor_session)
    moderator.update_attributes(:caller_session_id => self.id, :call_sid => call_sid) unless moderator.nil?
    response
  end
  


  def pause_for_results(attempt = 0)
    attempt = attempt.to_i || 0
    self.publish("waiting_for_result", {}) if attempt == 0
    Twilio::Verb.new { |v| v.say("Please enter your call results") if (attempt % 5 == 0); v.pause("length" => 2); v.redirect(pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id, :attempt=>attempt+1)) }.response
  end
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    self.update_attributes(:campaign => caller.campaign)
    Moderator.publish_event(campaign, "caller_re_assigned_to_campaign", {:caller_session_id => id, :caller_id => caller.id, :campaign_fields => {:id => campaign.id, :campaign_name => campaign.name, :callers_logged_in => campaign.caller_sessions.on_call.length,
      :voters_count => Voter.remaining_voters_count_for('campaign_id', campaign.id), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size }, :old_campaign_id => old_campaign.id,:no_of_callers_logged_in_old_campaign => old_campaign.caller_sessions.on_call.length})
    if caller.is_phones_only? 
      read_campaign_reassign_msg
    else
      next_voter = caller.campaign.next_voter_in_dial_queue
      self.publish("caller_re_assigned_to_campaign",{:campaign_name => caller.campaign.name, :campaign_id => caller.campaign.id, :script => caller.campaign.script.try(:script)}.merge!(next_voter ? next_voter.info : {}))
    end
  end
  
  def read_campaign_reassign_msg
    Twilio::Verb.new do |v|
      v.say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
      v.redirect(choose_instructions_option_caller_url(self.caller, :host => Settings.host, :port => Settings.port, :session => id, :Digits => "*"))
    end.response
  end
   
   def caller_reassigned_to_another_campaign?
      caller.campaign.id != self.campaign.id
   end

  def next_question
    voter_in_progress.question_not_answered
  end

  def end
    self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
            :no_of_callers_logged_in => campaign.caller_sessions.on_call.length})
    attempt_in_progress.try(:update_attributes, {:wrapup_time => Time.now})
    attempt_in_progress.try(:capture_answer_as_no_response)
    self.publish("caller_disconnected", {source: "end_call"})
    Twilio::Verb.hangup
  end

  def disconnected?
    !available_for_call && !on_call
  end
  
  def time_exceed_hangup
    Twilio::Verb.new do |v|
      v.say I18n.t(:campaign_time_period_exceed, :start_time => @campaign.start_time.hour <= 12 ? "#{@campaign.start_time.hour} AM" : "#{@campaign.start_time.hour-12} PM",
      :end_time => @campaign.end_time.hour <= 12 ? "#{@campaign.end_time.hour} AM" : "#{@campaign.end_time.hour-12} PM")
      v.hangup
    end.response
  end


  def publish(event, data)
    return unless self.campaign.use_web_ui?
    Rails.logger.debug("PUSHER APP ID ::::::::::::::::::::::::::::::::::::::  #{Pusher.app_id}////////////////////////////#{event}")
    Pusher[self.session_key].trigger(event, data.merge!(:dialer => self.campaign.predictive_type))
  end
  
  def get_conference_id
     Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
     conferences = Twilio::Conference.list({"FriendlyName" => session_key})
     confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
     conference_sid = ""
     conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
   end

  private
  
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end

  def caller_response_path
    if caller.is_phones_only?
      gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)
    else
      pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)
    end
  end
      
  def say_voter_name_ask_caller_to_choose_voter(voter, caller_choice)
    if caller_choice.present?
      (msg = I18n.t(:read_star_to_dial_pound_to_skip))  unless ["*","#"].include? caller_choice
    else
      msg = I18n.t(:read_voter_name, :first_name => voter.FirstName, :last_name => voter.LastName) 
    end
    Twilio::Verb.new do |v|
      v.gather(:numDigits => 1, :timeout => 10, :action => choose_voter_caller_url(self.caller, :session => self, :host => Settings.host, :port => Settings.port, :voter => voter), :method => "POST", :finishOnKey => "5") do
        v.say msg
      end
    end.response
  end
  
  def say_voter_name_and_call(voter)
    Twilio::Verb.new do |v|
      v.say "#{voter.FirstName}  #{voter.LastName}." 
      v.redirect(phones_only_progressive_caller_url(caller, :session_id => id, :voter_id => voter.id, :host => Settings.host, :port => Settings.port), :method => "POST")
    end.response
  end
end
