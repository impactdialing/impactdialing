class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include Event
  
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  
  scope :not_on_call, :conditions => {:on_call => false}
  scope :connected_to_voter, where('voter_in_progress is not null')
  scope :held_for_duration, lambda { |minutes| {:conditions => ["hold_time_start <= ?", minutes.ago]} }
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :on_campaign, lambda{|campaign| where("campaign_id = #{campaign.id}") unless campaign.nil?}  
  scope :for_caller, lambda{|caller| where("caller_id = #{caller.id}") unless caller.nil?}  
  has_one :voter_in_progress, :class_name => 'Voter'
  has_one :attempt_in_progress, :class_name => 'CallAttempt'
  has_one :moderator
  has_many :transfer_attempts
  
  delegate :subscription_allows_caller?, :to => :caller
  delegate :activated?, :to => :caller


  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
  
  def run(event,render_twiml=true)
      send(event)
      render if render_twiml
  end
  
  
  call_flow :state, :initial => :initial do    
    
      state [:initial, :connected] do
        event :start_conf, :to => :account_not_activated, :if => :account_not_activated?
        event :start_conf, :to => :subscription_limit, :if => :subscription_limit_exceeded?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?
        event :start_conf, :to => :caller_on_call,  :if => :is_on_call?
        event :start_conf, :to => :disconnected, :if => :disconnected?
      end 
      
      state all - [:initial] do
        event :end_conf, :to => :conference_ended
      end
      
      state :subscription_limit do
        
        response do |xml_builder, the_call|
          xml_builder.Say("The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.")
          xml_builder.Hangup          
        end
        
      end
      
      state :account_not_activated do
        response do |xml_builder, the_call|          
          xml_builder.Say "Your account has insufficent funds"
          xml_builder.Hangup
        end        
      end
      
      state :caller_on_call do
        response do |xml_builder, the_call|
          xml_builder.Say I18n.t(:indentical_caller_on_call)
          xml_builder.Hangup
        end
        
      end
      
      state :time_period_exceeded do                        
        response do |xml_builder, the_call|          
          xml_builder.Say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
          xml_builder.Hangup
        end        
      end
      
      state :disconnected do        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
      end
      
      
      state :conference_ended do
        before(:always) {end_caller_session}
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
                
      end
      
  end
  
  def end_caller_session
    update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    # Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
    #         :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})
    attempt_in_progress.try(:update_attributes, {:wrapup_time => Time.now})
    attempt_in_progress.try(:capture_answer_as_no_response)
    # self.publish("caller_disconnected", {source: "end_call"})    
  end
  
  def account_not_activated?
    !activated?
  end
  
  def subscription_limit_exceeded?
    !subscription_allows_caller?
  end
  
  def time_period_exceeded?
    campaign.time_period_exceeded?
  end
  
  def is_on_call?
    caller.is_on_call?
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
    attempt = voter.call_attempts.create(:campaign => self.campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self, status: CallAttempt::Status::RINGING)
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
    Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id,:dials_in_progress => campaign.call_attempts.not_wrapped_up.size})
    attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
  end
  
  def start_conference    
    reassign_caller_session_to_campaign if caller_reassigned_to_another_campaign?
    begin
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    rescue ActiveRecord::StaleObjectError
      # end conf
    end
  end


  def start
    wrapup
    unless endtime.nil?
      return Twilio::Verb.hangup
    end
    
    begin
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
      if campaign.type == Campaign::Type::PREVIEW || campaign.type == Campaign::Type::PROGRESSIVE
        publish('conference_started', {}) 
      else
        publish('caller_connected_dialer', {})
      end
    rescue ActiveRecord::StaleObjectError
      Rails.logger.debug("Stale object for #{self.inspect}")
    end
    response
  end
  
  def phones_only_start
    unless endtime.nil?
      return Twilio::Verb.hangup
    end
    begin
      response = Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true, :action => gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id)) do
          v.conference(session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
        end
      end.response
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    rescue ActiveRecord::StaleObjectError
      Rails.logger.debug("Stale object for #{self.inspect}")
    end    
    response
  end
  
  def ask_caller_to_choose_voter(voter = nil, caller_choice = nil)
    return reassign_caller_session_to_campaign if caller_reassigned_to_another_campaign?
    if campaign.time_period_exceed?
      time_exceed_hangup 
    else
      voter ||= campaign.next_voter_in_dial_queue
      if voter.present?
        campaign.type == Campaign::Type::PREVIEW ? say_voter_name_ask_caller_to_choose_voter(voter, caller_choice) : say_voter_name_and_call(voter)
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
    unless endtime.nil?
      return Twilio::Verb.hangup
    end    
    attempt = attempt.to_i || 0
    self.publish("waiting_for_result", {}) if attempt == 0
    Twilio::Verb.new { |v| v.say("Please enter your call results") if (attempt % 5 == 0); v.pause("length" => 11); v.redirect(pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id, :attempt=>attempt+1)) }.response
  end
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    update_attribute(:campaign, caller.campaign)
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
            :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})
    attempt_in_progress.try(:update_attributes, {:wrapup_time => Time.now})
    attempt_in_progress.try(:capture_answer_as_no_response)
    self.publish("caller_disconnected", {source: "end_call"})
    Twilio::Verb.hangup
  end

  def disconnected?
    !available_for_call && !on_call
  end
  


  def publish(event, data)
    return unless campaign.use_web_ui?
    Pusher[self.session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  
  def get_conference_id
     Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
     conferences = Twilio::Conference.list({"FriendlyName" => session_key})
     confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
     conference_sid = ""
     conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
   end
   
   def preview_voter
     if campaign.type == Campaign::Type::PREVIEW || campaign.type == Campaign::Type::PROGRESSIVE
       voter = campaign.next_voter_in_dial_queue      
       voter.update_attributes(caller_id: caller_id) unless voter.nil?
       voter_info = voter ? voter.info : {}
       voter_info.merge!({start_calling: true})
       publish('caller_connected_initial', voter_info) 
     else
       publish('caller_connected_dialer', {})
     end     
   end


   def debit
     return false if self.endtime.nil? || self.starttime.nil?
     call_time = ((self.endtime - self.starttime)/60).ceil
     Payment.debit(call_time, self)
   end
   
   def self.time_logged_in(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).sum('TIMESTAMPDIFF(SECOND ,starttime,endtime)')
   end
   
   def self.caller_time(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).where("tCaller is NOT NULL").sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)').to_i
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
