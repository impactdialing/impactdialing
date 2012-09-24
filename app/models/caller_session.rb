class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include CallerEvents
  include CallPayment
  
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}
  scope :not_available, :conditions => {:available_for_call => false, :on_call => true}
  
  scope :not_on_call, :conditions => {:on_call => false}
  scope :connected_to_voter, where('voter_in_progress is not null')
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :on_campaign, lambda{|campaign| where("campaign_id = #{campaign.id}") unless campaign.nil?}  
  scope :for_caller, lambda{|caller| where("caller_id = #{caller.id}") unless caller.nil?}  
  scope :debit_not_processed, lambda { where(:debited => "0", :caller_type => CallerType::PHONE).where('endtime is not null') }
  scope :campaigns_on_call, select("campaign_id").on_call.group("campaign_id")
  scope :first_caller_time, lambda { |caller| {:select => "created_at", :conditions => ["caller_id = ?", caller.id], :order => "created_at ASC", :limit => 1}  unless caller.nil?}
  scope :last_caller_time, lambda { |caller| {:select => "created_at", :conditions => ["caller_id = ?", caller.id], :order => "created_at DESC", :limit => 1}  unless caller.nil?}
  scope :first_campaign_time, lambda { |campaign| {:select => "created_at", :conditions => ["campaign_id = ?", campaign.id], :order => "created_at ASC", :limit => 1}  unless campaign.nil?}
  scope :last_campaign_time, lambda { |campaign| {:select => "created_at", :conditions => ["campaign_id = ?", campaign.id], :order => "created_at DESC", :limit => 1}  unless campaign.nil?}

  
  has_one :voter_in_progress, :class_name => 'Voter'
  has_one :attempt_in_progress, :class_name => 'CallAttempt'
  has_one :moderator
  has_many :transfer_attempts
  
  delegate :subscription_allows_caller?, :to => :caller
  delegate :activated?, :to => :caller
  delegate :funds_available?, :to => :caller
  
  module CallerType
    TWILIO_CLIENT = "Twilio client"
    PHONE = "Phone"
  end


  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end
  
  def run(event)
    begin
      caller_flow = self.method(event.to_s) 
      caller_flow.call      
    rescue ActiveRecord::StaleObjectError => exception
      reloaded_caller_session = CallerSession.find(self.id)
      reloaded_caller_session.send(event)
    end
    render
  end
  
  def process(event)
    begin
      caller_flow = self.method(event.to_s) 
      caller_flow.call      

    rescue ActiveRecord::StaleObjectError => exception
      reloaded_caller_session = CallerSession.find(self.id)
      reloaded_caller_session.send(event)
    end
  end
  
  
  
  call_flow :state, :initial => :initial do    
      
      state :initial do
        event :start_conf, :to => :account_not_activated, :if => :account_not_activated?
        event :start_conf, :to => :account_has_no_funds, :if => :funds_not_available?
        event :start_conf, :to => :subscription_limit, :if => :subscription_limit_exceeded?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?
        event :start_conf, :to => :caller_on_call,  :if => :is_on_call?
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

      state :account_has_no_funds do
        response do |xml_builder, the_call|
          xml_builder.Say("There are no funds available in the account.  Please visit the billing area of the website to add funds to your account.")
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
          xml_builder.Say I18n.t(:identical_caller_on_call)
          xml_builder.Hangup
        end
        
      end
      
      state :time_period_exceeded do                      
        response do |xml_builder, the_call|          
          xml_builder.Say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
          xml_builder.Hangup
        end        
      end
      
      state :conference_ended do
        before(:always) { end_caller_session}
        after(:always) {Resque.enqueue(CallerPusherJob, self.id, "publish_caller_disconnected") ; Resque.enqueue(ModeratorCallerJob, self.id, "publish_moderator_caller_disconnected")} 
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
                
      end
      
      
  end
  
  def end_caller_session
    begin
      end_session
      wrapup_attempt_in_progress
    rescue ActiveRecord::StaleObjectError => exception
      Resque.enqueue(PhantomCallerJob, self.id)
    end      
  end
  
  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)    
    voters = Voter.find_all_by_caller_id_and_status(caller.id, CallAttempt::Status::READY)
    voters.each {|voter| voter.update_attributes(status: 'not called')}    
    EM.run {
      t = TwilioLib.new(account, auth)    
      deferrable = t.end_call("#{self.sid}")              
      deferrable.callback {}
      deferrable.errback { |error| }          
    }             
    end_caller_session
    CallAttempt.wrapup_calls(caller_id)
    Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
    :no_of_callers_logged_in => campaign.caller_sessions.on_call.length})
  end  
  
  
  def wrapup_attempt_in_progress
    attempt_in_progress.try(:update_attributes, {:wrapup_time => Time.now})
  end
  
  def end_session
    update_attributes(on_call: false, available_for_call:  false, endtime:  Time.now)
  end
  
  def account_not_activated?
    !activated?
  end
  
  def subscription_limit_exceeded?
    !subscription_allows_caller?
  end
  
  def funds_not_available?
    !funds_available?
  end
  
  def time_period_exceeded?
    campaign.time_period_exceeded?
  end
  
  def is_on_call?
    caller.is_on_call?
  end
    
  def hold
    Twilio::Verb.new { |v| v.play "#{Settings.host}:#{Settings.port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end
  
  def redirect_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, flow_caller_url(caller, :host => Settings.host, :port => Settings.port, session_id: id, event: "start_conf"))
  end
  

  def join_conference(mute_type, call_sid, monitor_session)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod =>"GET", :muted => mute_type)
      end
    end.response
    moderator = Moderator.find_by_session(monitor_session)
    moderator.update_attributes(:caller_session_id => self.id, :call_sid => call_sid) unless moderator.nil?
    response
  end
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    update_attribute(:campaign, caller.campaign)    
    publish_moderator_caller_reassigned_to_campaign(old_campaign)
  end
     
  def caller_reassigned_to_another_campaign?
    caller.campaign.id != self.campaign.id
  end

  def disconnected?
    !available_for_call && !on_call
  end
  
  def publish(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  
    
  def dial_em(voter)
    return if voter.nil?
    call_attempt = create_call_attempt(voter)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)        
    EM.run do
      http = twilio_lib.make_call_em(campaign, voter, call_attempt)
      http.callback { 
        response = JSON.parse(http.response)  
        if response["RestException"]
          handle_failed_call(call_attempt, self)
        else
          call_attempt.update_attributes(:sid => response["sid"])
        end
        EM.stop
         }
      http.errback {EM.stop}            
    end
  end
  
  def create_call_attempt(voter)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller, call_start:  Time.now)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt, all_states: "", state: 'initial')
    attempt    
  end
  
  
  def make_call(attempt, voter)
  Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => flow_call_url(attempt.call, host: Settings.host, port:  Settings.port, event: "call_ended"),'Timeout' => campaign.use_recordings? ? "20" : "15"}
  params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect        
  Twilio::Call.make(self.campaign.caller_id, voter.Phone, flow_call_url(attempt.call, host: Settings.host, port: Settings.port, event: "incoming_call"),params)  
  end
  
  def handle_failed_call(attempt, voter)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    Moderator.update_dials_in_progress(campaign)
    redirect_caller
  end
  
  
  def get_conference_id
     Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
     conferences = Twilio::Conference.list({"FriendlyName" => session_key})
     confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
     conference_sid = ""
     conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
   end
   
   
   def self.time_logged_in(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).sum('TIMESTAMPDIFF(SECOND ,starttime,endtime)').to_i
   end
   
   def self.caller_time(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).where("caller_type = 'Phone' ").sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)').to_i
   end   
   
   def call_not_connected?
     starttime.nil? || endtime.nil? || caller_type == nil || caller_type == CallerType::TWILIO_CLIENT
   end

   def call_time
   ((endtime - starttime)/60).ceil
   end
   
   
  private
    
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end
      
end
