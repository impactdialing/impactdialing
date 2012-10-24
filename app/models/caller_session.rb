class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include CallerEvents
  include CallPayment
  include SidekiqEvents
  include CallerTwiml
  
  after_save :expire_find_by_id_cache, :expire_find_by_call_sid_cache
  after_create :expire_find_by_id_cache, :expire_find_by_call_sid_cache

  
  belongs_to :caller
  belongs_to :campaign

  scope :on_call, :conditions => {:on_call => true}
  scope :available, :conditions => {:available_for_call => true, :on_call => true}  
  scope :not_available, :conditions => {:available_for_call => false, :on_call => true}  
  scope :connected_to_voter, where('voter_in_progress is not null')
  scope :between, lambda { |from_date, to_date| {:conditions => {:created_at => from_date..to_date}} }
  scope :on_campaign, lambda{|campaign| where("campaign_id = #{campaign.id}") unless campaign.nil?}  
  scope :for_caller, lambda{|caller| where("caller_id = #{caller.id}") unless caller.nil?}  
  scope :debit_not_processed, lambda { where(:debited => "0", :caller_type => CallerType::PHONE).where('tEndTime is not null') }
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
  
  def start_conf
    return account_not_activated_twiml if account_not_activated?
    return account_has_no_funds_twiml if funds_not_available?
    return subscription_limit_twiml if subscription_limit_exceeded?
    return time_period_exceeded_twiml if time_period_exceeded?
    return caller_on_call_twiml if is_on_call?    
  end
  
  def campaign_out_of_phone_numbers
    campaign_out_of_phone_numbers_twiml
  end
  
  def time_period_exceeded
    time_period_exceeded_twiml
  end
  
  def account_has_no_funds
    account_has_no_funds_twiml
  end
  
  def conference_ended
    end_caller_session
    enqueue_call_flow(CallerPusherJob, [self.id, "publish_caller_disconnected"])
    conference_ended_twiml
  end
  
  
  def end_caller_session
    begin
      end_session     
    rescue ActiveRecord::StaleObjectError => exception
    end      
  end
  
  def end_running_call
    end_caller_session
    enqueue_call_flow(EndRunningCallJob, [self.sid])
    enqueue_call_flow(EndCallerSessionJob, [self.id])
  end  
  
  
  def end_session
    self.update_attributes(endtime: Time.now, on_call: false, available_for_call: false)
    RedisPredictiveCampaign.remove(campaign_id, campaign.type) if campaign.caller_sessions.on_call.size <= 1
    RedisStatus.delete_state(campaign_id, self.id)
    RedisCallerSession.delete(self.id)
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
    if caller.is_phones_only?
      Twilio::Call.redirect(sid, ready_to_call_caller_url(caller_id, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id))      
    else
      Twilio::Call.redirect(sid, continue_conf_caller_url(caller_id, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id))      
    end    
    
  end
  
  def redirect_caller_out_of_numbers
    if self.available_for_call?
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, run_out_of_numbers_caller_url(caller_id, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id))
    end
  end
  
  def redirect_caller_time_period_exceeded
    if self.available_for_call?
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, time_period_exceeded_caller_url(caller_id, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id))
    end    
  end

  def redirect_account_has_no_funds
    if self.available_for_call?
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, account_out_of_funds_caller_url(caller, :host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, session_id: id))
    end    
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
    on_call == false
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
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).sum('TIMESTAMPDIFF(SECOND ,tStartTime,tEndTime)').to_i
   end
   
   def self.caller_time(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).where("caller_type = 'Phone' ").sum('ceil(TIMESTAMPDIFF(SECOND ,tStartTime,tEndTime)/60)').to_i
   end   
   
   def call_not_connected?
     tStartTime.nil? || tEndTime.nil? || caller_type == nil || caller_type == CallerType::TWILIO_CLIENT
   end

   def call_time
   ((tEndTime - tStartTime)/60).ceil
   end
   
   def start_conference
     if Campaign.predictive_campaign?(campaign.type)
       self.update_attributes(on_call: true, available_for_call: true)
       RedisOnHoldCaller.remove_caller_session(campaign_id, self.id)
       RedisOnHoldCaller.add(campaign_id, self.id)
     end     
   end

  def assigned_to_lead?
    self.on_call && !self.available_for_call
  end

  
  def self.find_by_id_cached(id)
    Rails.cache.fetch("CallerSession.find_by_id(#{id})") { CallerSession.find_by_id(id) }
  end
  
  def self.find_by_sid_cached(sid)
    Rails.cache.fetch("CallerSession.find_by_sid(#{sid})") { CallerSession.find_by_sid(sid) }
  end
  
  def expire_find_by_id_cache
    Rails.cache.delete('CallerSession.find_by_id(#{id})')
  end

  def expire_find_by_call_sid_cache
    Rails.cache.delete('CallerSession.find_by_sid(#{sid})')
  end
  
  
  private
    
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end
      
end