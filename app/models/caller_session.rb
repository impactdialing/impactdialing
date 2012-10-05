require 'new_relic/agent/method_tracer'

class CallerSession < ActiveRecord::Base
  include ::NewRelic::Agent::MethodTracer
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
        after(:always) {  enqueue_call_flow(CallerPusherJob, [self.id, "publish_caller_disconnected"]);enqueue_moderator_flow(ModeratorCallerJob, [self.id,  "publish_moderator_caller_disconnected"])} 
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
      wrapup_attempt_in_progress      
    rescue ActiveRecord::StaleObjectError => exception
      Resque.enqueue(PhantomCallerJob, self.id)
    end      
  end
  
  def end_session
    RedisCallerSession.end_session(self.id)
    RedisCaller.disconnect_caller(campaign.id, self.id )
    if campaign.type == Campaign::Type::PREDICTIVE && RedisCaller.zero?(campaign.id)
      RedisCampaign.remove_running_predictive_campaign(campaign.id)
    end
  end
  
  
  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)    
    end_caller_session
    enqueue_call_flow(EndRunningCallJob, [self.sid])
    enqueue_call_flow(EndCallerSessionJob, [self.id])
  end  
  
  
  def wrapup_attempt_in_progress
    redis_attempt_in_progress = RedisCallerSession.attempt_in_progress(self.id)    
    unless redis_attempt_in_progress.blank?
      RedisCampaignCall.move_to_completed(campaign.id, redis_attempt_in_progress)
      RedisCallAttempt.wrapup(redis_attempt_in_progress)
    end
    
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
    MonitorConference.join_conference(monitor_session, self.id, call_sid)
    response
  end
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    update_attribute(:campaign, caller.campaign)    
    # publish_moderator_caller_reassigned_to_campaign(old_campaign)
  end
     
  def caller_reassigned_to_another_campaign?
    caller.campaign.id != self.campaign.id
  end

  def disconnected?
    RedisCaller.disconnected?(campaign.id, self.id)
  end
  
  def publish(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  
    
  def dial(voter)
    return if voter.nil?
    call_attempt = create_call_attempt(voter)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)        
    http_response = twilio_lib.make_call(campaign, voter, call_attempt)
    response = JSON.parse(http_response)  
    if response["RestException"]
      handle_failed_call(call_attempt, self)
    else
      call_attempt.update_attributes(:sid => response["sid"])
    end
  end
  
  def create_call_attempt(voter)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session_id => self.id, :caller_id => caller.id, call_start:  Time.now)
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, :caller_session_id => self.id, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt, all_states: "", state: 'initial')    
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt)
      RedisVoter.setup_call(voter.id, attempt.id, self.id)
      RedisCallerSession.set_attempt_in_progress(self.id, attempt.id)
    end
    RedisCampaignCall.add_to_ringing(campaign.id, attempt.id)
    attempt    
  end
  
  
  def handle_failed_call(attempt, voter)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
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
   
   def start_conference    
     RedisCallerSession.start_conference(self.id)
     RedisCaller.move_to_on_hold(campaign.id, self.id)
   end
   

  #NewRelic custom metrics
  add_method_tracer :account_not_activated?,                 'Custom/CallerSession/account_not_activated?'
  add_method_tracer :subscription_limit_exceeded?,           'Custom/CallerSession/subscription_limit_exceeded?'
  add_method_tracer :funds_not_available?,                   'Custom/CallerSession/funds_not_available?'
  add_method_tracer :time_period_exceeded?,                  'Custom/CallerSession/time_period_exceeded?'
  add_method_tracer :is_on_call?,                            'Custom/CallerSession/is_on_call?'
  add_method_tracer :caller_reassigned_to_another_campaign?, 'Custom/CallerSession/caller_reassigned_to_another_campaign?'
  add_method_tracer :disconnected?,                          'Custom/CallerSession/disconnected?'

  private
    
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end
      
end
