class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include CallerEvents
  include CallPayment
  include SidekiqEvents
  
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}  
  scope :not_available, :conditions => {:available_for_call => false, :on_call => true}  
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
        after(:always) {  enqueue_call_flow(CallerPusherJob, [self.id, "publish_caller_disconnected"])} 
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
                
      end
      
      state :campaign_out_of_phone_numbers do
        response do |xml_builder, the_call|          
          xml_builder.Say I18n.t(:campaign_out_of_phone_numbers)
          xml_builder.Hangup
        end                
      end
      
      
  end
  
  
  def end_caller_session
    begin
      end_session     
    rescue ActiveRecord::StaleObjectError => exception
      Resque.enqueue(PhantomCallerJob, self.id)
    end      
  end
  
  def end_running_call
    end_caller_session
    enqueue_call_flow(EndRunningCallJob, [self.sid])
    enqueue_call_flow(EndCallerSessionJob, [self.id])
  end  
  
  
  def end_session
    self.update_attributes(endtime: Time.now, on_call: false, available_for_call: false)
    RedisPredictiveCampaign.remove(campaign.id, campaign.type) if campaign.caller_sessions.on_call.size <= 1
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
    Twilio::Verb.new { |v| v.play "#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end
  
  def redirect_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, flow_caller_url(caller, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id, event: "start_conf"))
  end
  
  def redirect_caller_out_of_numbers
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, flow_caller_url(caller, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id, event: "run_ot_of_phone_numbers"))
  end
  

  def join_conference(mute_type, call_sid, monitor_session)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod =>"GET", :muted => mute_type)
      end
    end.response
    response
  end
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    update_attribute(:campaign, caller.campaign)    
  end
     
  def caller_reassigned_to_another_campaign?
    caller.campaign.id != self.campaign.id
  end
  

  def disconnected?
    state == "conference_ended"
  end
  
  def publish(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
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
   
   def start_conference
     if Campaign.predictive_campaign?(campaign.type)
       self.update_attributes(on_call: true, available_for_call: true)
       RedisOnHoldCaller.remove_caller_session(campaign.id, self.id)
       RedisOnHoldCaller.add(campaign.id, self.id)
     end     
   end

  def assigned_to_lead?
    self.on_call && !self.available_for_call
  end

  def on_call_states
    ['']
  end

  private
    
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end
      
end