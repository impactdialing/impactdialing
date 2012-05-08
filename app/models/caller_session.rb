class CallerSession < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include CallerEvents
  
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
  scope :debit_not_processed, where(debited: "0").where('call_end is not null')
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
  
  def run(event)
      send(event)
      render
  end
  
  def process(event)
    send(event)
  end
  
  
  call_flow :state, :initial => :initial do    
      
      state :initial do
        event :start_conf, :to => :account_not_activated, :if => :account_not_activated?
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
      
      state :conference_ended do
        before(:always) { end_caller_session}
        after(:always) { publish_caller_disconnected; publish_moderator_caller_disconnected} 
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
                
      end
      
      
  end
  
  def end_caller_session
    begin
      end_session
    rescue ActiveRecord::StaleObjectError
      reload
      end_session
    end      
    attempt_in_progress.try(:update_attributes, {:wrapup_time => Time.now})
    attempt_in_progress.try(:capture_answer_as_no_response)
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
  
  def time_period_exceeded?
    campaign.time_period_exceeded?
  end
  
  def is_on_call?
    caller.is_on_call?
  end
    
  def hold
    Twilio::Verb.new { |v| v.play "#{Settings.host}:#{Settings.port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
  end
  
  
  def redirect_to_phones_only_start
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, phones_only_caller_index_url(:host => Settings.host, :port => Settings.port, session_id: id, :campaign_reassigned => caller_reassigned_to_another_campaign?))
  end
  
  def redirect_webui_caller
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(sid, flow_caller_url(caller, :host => Settings.host, :port => Settings.port, session_id: id, event: "start_conf"))
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
  
  def reassign_caller_session_to_campaign
    old_campaign = self.campaign
    update_attribute(:campaign, caller.campaign)    
    # publish_moderator_caller_reassigned_to_campaign(old_campaign)
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
  
  def end_running_call(account=TWILIO_ACCOUNT, auth=TWILIO_AUTH)    
    voters = Voter.find_all_by_caller_id_and_status(caller.id, CallAttempt::Status::READY)
    voters.each {|voter| voter.update_attributes(status: 'not called')}    
    t = ::TwilioLib.new(account, auth)
    t.end_call("#{self.sid}")
    begin
      end_caller_session
      CallAttempt.wrapup_calls(caller_id)
    rescue ActiveRecord::StaleObjectError
      reload
      end_caller_session
    end      
        
  end  
  
  def dial(voter)
    attempt = create_call_attempt(voter)
    publish_calling_voter
    make_call(attempt,voter)    
  end
  
  def create_call_attempt(voter)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt)
    attempt    
  end
  
  
  def make_call(attempt, voter)
    EM.run {
      t = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)    
      deferrable = t.make_call(campaign, voter, attempt)              
      deferrable.callback {
       # if deferrable.response["TwilioResponse"]["RestException"]
       #   handle_failed_call(attempt, voter)
       # else
         attempt.update_attributes(:sid => deferrable.response["sid"])
       # end
      }
      deferrable.errback { |error| }          
    }             
  end
  
  def handle_failed_call(attempt, voter)
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    Moderator.update_dials_in_progress(campaign)
    redirect_webui_caller
  end
  
  
  def get_conference_id
     Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
     conferences = Twilio::Conference.list({"FriendlyName" => session_key})
     confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
     conference_sid = ""
     conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
   end
   
   def debit
     return false if self.endtime.nil? || self.starttime.nil?
     call_time = ((self.endtime - self.starttime)/60).ceil
     Payment.debit(call_time, self)
   end
   
   def self.time_logged_in(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).sum('TIMESTAMPDIFF(SECOND ,starttime,endtime)').to_i
   end
   
   def self.caller_time(caller, campaign, from, to)
     CallerSession.for_caller(caller).on_campaign(campaign).between(from, to).where("tCaller is NOT NULL").sum('ceil(TIMESTAMPDIFF(SECOND ,starttime,endtime)/60)').to_i
   end
   
  private
    
  def wrapup
    attempt_in_progress.try(:wrapup_now)
  end
      
end
