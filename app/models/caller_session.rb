class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallerEvents
  include CallPayment
  include SidekiqEvents
  include CallerTwiml


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
  delegate :funds_available?, :to => :caller

  module CallerType
    TWILIO_CLIENT = "Twilio client"
    PHONE = "Phone"
  end

  module ReassignCampaign
    NO = "no"
    YES = "yes"
    DONE = "done"
  end


  def minutes_used
    return 0 if self.tDuration.blank?
    self.tDuration/60.ceil
  end

  def start_conf
    return account_has_no_funds_twiml if funds_not_available?
    return subscription_limit_twiml if subscription_limit_exceeded?
    return time_period_exceeded_twiml if time_period_exceeded?
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
      RedisCallerSession.add_phantom_callers(self.id)
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
    RedisOnHoldCaller.remove_caller_session(campaign_id, self.id, data_centre)
    RedisDataCentre.remove_data_centre(campaign_id, data_centre)
    RedisCallerSession.remove_datacentre(self.id)
  end


  def account_not_activated?
    account.is_activated?
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
    Twilio::Verb.new { |v| v.play "#{DataCentre.call_back_host(data_centre)}:#{Settings.twilio_callback_port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end

  def redirect_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    if caller.is_phones_only?
      Twilio::Call.redirect(sid, ready_to_call_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", session_id: id))
    else
      Twilio::Call.redirect(sid, continue_conf_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", session_id: id))
    end

  end

  def redirect_caller_out_of_numbers
    if self.available_for_call? || campaign.type != Campaign::Type::PREDICTIVE
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, run_out_of_numbers_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", session_id: id))
    end
  end

  def redirect_caller_time_period_exceeded
    if self.available_for_call? || campaign.type != Campaign::Type::PREDICTIVE
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, time_period_exceeded_caller_url(caller_id, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", session_id: id))
    end
  end

  def redirect_account_has_no_funds
    if self.available_for_call? || campaign.type != Campaign::Type::PREDICTIVE
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      Twilio::Call.redirect(sid, account_out_of_funds_caller_url(caller, :host => DataCentre.call_back_host(data_centre), :port => Settings.twilio_callback_port, :protocol => "http://", session_id: id))
    end
  end


  def join_conference(mute_type)
    response = Twilio::Verb.new do |v|
      v.dial(:hangupOnStar => true) do
        v.conference(self.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => HOLD_MUSIC_URL, :waitMethod =>"GET", :muted => mute_type)
      end
    end.response
    response
  end

  def reassign_to_another_campaign(new_campaign_id)
    update_attributes(reassign_campaign: ReassignCampaign::YES)
    RedisReassignedCallerSession.set_campaign_id(self.id, new_campaign_id)
  end

  def reassigned_to_another_campaign?
    self.reassign_campaign == ReassignCampaign::YES
  end


  def handle_reassign_campaign(callerdc=DataCentre::Code::TWILIO)
    if reassigned_to_another_campaign?
      new_campaign_id = RedisReassignedCallerSession.campaign_id(self.id)
      new_campaign =  Campaign.find(new_campaign_id)
      RedisPredictiveCampaign.remove(campaign.id, campaign.type) if campaign.caller_sessions.on_call.size <= 1
      RedisDataCentre.remove_data_centre(campaign.id, callerdc)
      self.update_attributes(reassign_campaign: ReassignCampaign::DONE, campaign: new_campaign)
      RedisPredictiveCampaign.add(new_campaign.id, new_campaign.type)
      RedisReassignedCallerSession.delete(self.id)
      RedisStatus.set_state_changed_time(new_campaign.id, "On hold", self.id)
      RedisDataCentre.set_datacentres_used(new_campaign.id, callerdc)
    end
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
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).sum('tDuration').to_i
   end

   def self.caller_time(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).where("caller_type = 'Phone' ").sum('ceil(tDuration/60)').to_i
   end

   def call_not_connected?
     tStartTime.nil? || tEndTime.nil? || caller_type == nil || caller_type == CallerType::TWILIO_CLIENT
   end

   def call_time
   ((tDuration.to_f)/60).ceil
   end

   def start_conference(callerdc=DataCentre::Code::TWILIO)
     RedisCallerSession.set_datacentre(self.id, callerdc)
     handle_reassign_campaign(callerdc)
     if Campaign.predictive_campaign?(campaign.type)
       loaded_caller_session = CallerSession.find(self.id)
       loaded_caller_session.update_attributes(on_call: true, available_for_call: true)
       RedisOnHoldCaller.remove_caller_session(campaign_id, self.id, callerdc)
       RedisOnHoldCaller.add(campaign_id, self.id, callerdc)
     end
   end

  def assigned_to_lead?
    self.on_call && !self.available_for_call
  end


  def self.find_by_id_cached(id)
    CallerSession.find_by_id(id)
  end

  def self.find_by_sid_cached(sid)
    CallerSession.find_by_sid(sid)
  end

  def data_centre
    RedisCallerSession.datacentre(self.id)
  end

end
