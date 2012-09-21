class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter

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
  delegate :redis_caller_session, :to=> :call_attempt
  delegate :end_caller_session, :to=> :call_attempt
  delegate :caller_session_key, :to=> :call_attempt
  
  
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => (:answered_by_human_and_caller_available?)
        event :incoming_call, :to => :abandoned , :if => (:answered_by_human_and_caller_not_available?)
        event :incoming_call, :to => :call_answered_by_machine , :if => (:answered_by_machine?)
        event :call_ended, :to => :call_not_answered_by_lead, :if => :call_did_not_connect?
        event :call_ended, :to => :abandoned
      end 
      
      state :connected do
<<<<<<< HEAD
        after(:always) { connect_call; call_attempt.publish_voter_connected}
=======
        before(:always) {  connect_call }
        after(:always) { Resque.enqueue(CallPusherJob, call_attempt.id, "publish_voter_connected")}
>>>>>>> em
        event :hangup, :to => :hungup
        event :disconnect, :to => :disconnected
        
        response do |xml_builder, the_call|
          unless redis_caller_session.nil? 
            xml_builder.Dial :hangupOnStar => 'false', :action => flow_call_url(the_call, :host => Settings.host, event: "disconnect"), :record=> campaign.account.record_calls do |d|
              d.Conference caller_session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
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
<<<<<<< HEAD
        after(:success) { call_attempt.publish_voter_disconnected}                
=======
        after(:success) { Resque.enqueue(CallPusherJob, call_attempt.id, "publish_voter_disconnected") }                
>>>>>>> em
        event :call_ended, :to => :call_answered_by_lead, :if => :call_connected?
        event :call_ended, :to => :call_not_answered_by_lead, :if => :call_did_not_connect?        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :abandoned do
<<<<<<< HEAD
        before(:always) { abandon_call; call_attempt.redirect_caller }                
=======
        before(:always) { abandon_call; Resque.enqueue(RedirectCallerJob, call_attempt.id) }        
>>>>>>> em
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :call_answered_by_machine do
        event :call_ended, :to => :call_end_machine
        before(:always) { process_answered_by_machine; Resque.enqueue(RedirectCallerJob, call_attempt.id) }        
        
        response do |xml_builder, the_call|
          xml_builder.Play campaign.recording.file.url if campaign.use_recordings?
          xml_builder.Hangup
        end
      end
      
      state :call_answered_by_lead do
        before(:always) { end_answered_call }        
        event :submit_result, :to => :wrapup_and_continue
        event :submit_result_and_stop, :to => :wrapup_and_stop
        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end        
      end
      
      state :call_end_machine do
        before(:always) { end_answered_by_machine }                
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end
      
      
      state :call_not_answered_by_lead do
        before(:always) { end_unanswered_call; Resque.enqueue(RedirectCallerJob, call_attempt.id) }                
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end
      
      
      state :wrapup_and_continue do 
<<<<<<< HEAD
        before(:always) { wrapup_now; call_attempt.redirect_caller }
=======
        before(:always) { wrapup_now; Resque.enqueue(RedirectCallerJob, call_attempt.id);Resque.enqueue(ModeratorCallJob, call_attempt.id, "publish_moderator_response_submited") }
>>>>>>> em
        after(:success){ persist_all_states}
      end
      
      state :wrapup_and_stop do
        before(:always) { wrapup_now; end_caller_session }        
        after(:success){ persist_all_states;}
      end
            
  end 
  
  def persist_all_states
    update_attribute(:all_states, (all_states + "|" + state))
  end
  
  def run(event)
    send(event)
    render
  end
  
  def process(event)
    begin
      send(event)
    rescue ActiveRecord::StaleObjectError => exception      
      Resque.enqueue(PhantomCallerJob, caller_session.id)  unless caller_session.nil?
    end          
  end
  
  def answered_by_machine?
    answered_by == "machine"
  end

  def answered_by_human_and_caller_not_available?
    (answered_by.nil? || answered_by == "human") && call_status == 'in-progress' && caller_not_available?
  end
  
  def answered_by_human_and_caller_available?
    (answered_by.nil? || answered_by == "human") && call_status == 'in-progress' && caller_available?
  end
  
  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(call_status)
  end
  
  def call_connected?
    !call_did_not_connect?
  end
  
  
end  