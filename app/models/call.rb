class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include SidekiqEvents

  attr_accessible :id, :account_sid, :to_zip, :from_state, :called, :from_country, :caller_country, :called_zip, :direction, :from_city,
   :called_country, :caller_state, :call_sid, :called_state, :from, :caller_zip, :from_zip, :call_status, :to_city, :to_state, :to, :to_country, 
   :caller_city, :api_version, :caller, :called_city, :all_states, :state, :call_attempt, :questions, :notes, :answered_by
   
  has_one :call_attempt
  serialize :conference_history, Array
  delegate :connect_call, :to => :call_attempt
  delegate :abandon_call, :to => :call_attempt
  delegate :connect_lead_to_caller ,:to => :call_attempt
  delegate :end_answered_call, :to => :call_attempt
  delegate :end_unanswered_call, :to => :call_attempt
  delegate :end_answered_by_machine, :to => :call_attempt
  delegate :end_running_call, :to => :call_attempt
  delegate :disconnect_call, :to => :call_attempt
  delegate :wrapup_now, :to => :call_attempt
  delegate :wrapup_now, :to => :call_attempt
  
  delegate :process_answered_by_machine, :to => :call_attempt
  delegate :caller_not_available?, :to => :call_attempt
  delegate :caller_available?, :to => :call_attempt
  delegate :campaign, :to=> :call_attempt
  delegate :voter, :to=> :call_attempt
  delegate :caller_session, :to=> :call_attempt
  
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => (:answered_by_human_and_caller_available?)
        event :incoming_call, :to => :abandoned , :if => (:answered_by_human_and_caller_not_available?)
        event :incoming_call, :to => :call_answered_by_machine , :if => (:answered_by_machine?)
      end 
      
      state :connected do
        before(:always) {  connect_call }
        after(:always) { enqueue_call_flow(CallPusherJob, [call_attempt.id, "publish_voter_connected"]); enqueue_moderator_flow(ModeratorCallJob,[call_attempt.id, "publish_voter_event_moderator"])}
        event :hangup, :to => :hungup
        event :disconnect, :to => :disconnected
        
        response do |xml_builder, the_call|
          unless caller_session.nil? 
            xml_builder.Dial :hangupOnStar => 'false', :action => flow_call_url(the_call, :host => Settings.twilio_callback_host, event: "disconnect"), :record=> campaign.account.record_calls do |d|
              d.Conference caller_session.session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
            end
          else
            xml_builder.Hangup
          end
        end
        
      end
      
      state :hungup do
        before(:always) { end_running_call }
        event :disconnect, :to => :disconnected
      end
      
      state :disconnected do        
        before(:always) { disconnect_call }
        after(:success) { enqueue_call_flow(CallPusherJob, [call_attempt.id, "publish_voter_disconnected"]);Resque.enqueue(ModeratorCallJob, call_attempt.id, "publish_voter_event_moderator") }                
        event :submit_result, :to => :wrapup_and_continue
        event :submit_result_and_stop, :to => :wrapup_and_stop        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :abandoned do
        before(:always) { abandon_call; call_attempt.redirect_caller }        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :call_answered_by_machine do
        event :call_ended, :to => :call_end_machine
        before(:always) { process_answered_by_machine; call_attempt.redirect_caller }        
        
        response do |xml_builder, the_call|
          xml_builder.Play campaign.recording.file.url if campaign.use_recordings?
          xml_builder.Hangup
        end
      end
      
      
      state :call_end_machine do
        before(:always) { end_answered_by_machine }                
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end            
      
      state :wrapup_and_continue do 
        before(:always) { wrapup_now; call_attempt.redirect_caller; Resque.enqueue(ModeratorCallJob, call_attempt.id, "publish_voter_event_moderator") }
      end
      
      state :wrapup_and_stop do
        before(:always) { wrapup_now; caller_session.run('end_conf') }        
      end
            
  end 
  
  
  def run(event)
    call_flow = self.method(event.to_s) 
    call_flow.call
    render
  end
  
  def process(event)
    begin
      call_flow = self.method(event.to_s) 
      call_flow.call
    rescue ActiveRecord::StaleObjectError => exception      
      Resque.enqueue(PhantomCallerJob, caller_session.id)  unless caller_session.nil?
    end          
  end
  
  def answered_by_machine?
    answered_by == "machine"
  end

  def answered_by_human_and_caller_not_available?
    (answered_by.nil? || answered_by == "human") && caller_not_available?
  end
  
  def answered_by_human_and_caller_available?
    (answered_by.nil? || answered_by == "human") && caller_available?
  end
  
  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(call_status)
  end
  
  def call_connected?
    !call_did_not_connect?
  end
  
  
  
  
  
  
  
end  