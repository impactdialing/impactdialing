class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter


  attr_accessible :id, :account_sid, :to_zip, :from_state, :called, :from_country, :caller_country, :called_zip, :direction, :from_city,
   :called_country, :caller_state, :call_sid, :called_state, :from, :caller_zip, :from_zip, :call_status, :to_city, :to_state, :to, :to_country, 
   :caller_city, :api_version, :caller, :called_city, :all_states, :state, :call_attempt, :questions, :notes, :answered_by, :campaign_type
   
  has_one :call_attempt
  serialize :conference_history, Array
  delegate :connect_call, :to => :call_attempt  
  delegate :campaign, :to=> :call_attempt
  delegate :voter, :to=> :call_attempt
  delegate :caller_session, :to=> :call_attempt
  delegate :end_caller_session, :to=> :call_attempt
  delegate :caller_session_key, :to=> :call_attempt
  delegate :enqueue_call_flow, :to=> :call_attempt
  delegate :enqueue_dial_flow, :to=> :call_attempt
  
  
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => (:answered_by_human_and_caller_available?)
        event :incoming_call, :to => :abandoned , :if => (:answered_by_human_and_caller_not_available?)
        event :incoming_call, :to => :call_answered_by_machine , :if => (:answered_by_machine?)
      end 
      
      state :connected do
        event :hangup, :to => :hungup
        event :disconnect, :to => :disconnected
        
        before(:always) {  
          connect_call;
          if !Caller.where(caller_session_id: call_attempt.caller_session_id).select(:is_phones_only).is_phones_only?
            enqueue_call_flow(VoterConnectedPusherJob, [caller_session.id, self.id])
          end
          # enqueue_dial_flow(CampaignStatusJob, ["connected", campaign.id, call_attempt.id, caller_session.id])          
        }
        
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
      
      state :abandoned do
        
        before(:always) { 
          RedisCall.push_to_abandoned_call_list(self.id); 
          # enqueue_dial_flow(CampaignStatusJob, ["abandoned", campaign.id, call_attempt.id, nil])          
          call_attempt.redirect_caller
         }                
          
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      state :call_answered_by_machine do        
        
        before(:always) { 
          RedisCall.push_to_processing_by_machine_call_hash(self.id);
          # enqueue_dial_flow(CampaignStatusJob, ["answered_machine", campaign.id, call_attempt.id, nil])      
          call_attempt.redirect_caller }        
                  
        response do |xml_builder, the_call|
          xml_builder.Play campaign.recording.file.url if campaign.use_recordings?
          xml_builder.Hangup
        end
      end
      
      
      
      state :hungup do
        event :disconnect, :to => :disconnected
        
        before(:always) { 
            enqueue_call_flow(EndRunningCallJob, [call_attempt.sid])
          }         
        
      end
      
      state :disconnected do        
        event :submit_result, :to => :wrapup_and_continue
        event :submit_result_and_stop, :to => :wrapup_and_stop        
        
        before(:always) { 
          unless caller_session.nil?
            RedisCall.push_to_disconnected_call_list(self.id, self.recording_duration, self.recording_duration, caller_session.caller.id);
            # enqueue_dial_flow(CampaignStatusJob, ["disconnected", campaign.id, call_attempt.id, caller_session.id])          
          end
       }       
        after(:success) { 
          unless caller_session.nil?
            enqueue_call_flow(CallerPusherJob, [caller_session.id, "publish_voter_disconnected"])
          end
        }                
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
        
      end
      
      
      state :wrapup_and_continue do 
        before(:always) { 
        RedisCall.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
        # enqueue_dial_flow(CampaignStatusJob, ["wrapped_up", campaign.id, call_attempt.id, caller_session.id])
        call_attempt.redirect_caller
         }
      end
            
      state :wrapup_and_stop do
        before(:always) { 
        RedisCall.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
        # enqueue_dial_flow(CampaignStatusJob, ["wrapped_up", campaign.id, call_attempt.id, caller_session.id])       
        end_caller_session }        
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
  
  def answered_by_human?
    (answered_by.nil? || answered_by == "human")
  end
  
  def answered_by_human_and_caller_available?    
     answered_by_human?  && call_status == 'in-progress' && !caller_session.nil? && caller_session.assigned_to_lead?
  end

  
  def answered_by_human_and_caller_not_available?
    answered_by_human?  && call_status == 'in-progress' && (caller_session.nil? || !caller_session.assigned_to_lead?)
  end
  
  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(call_status)
  end
  
  def call_connected?
    !call_did_not_connect?
  end
  
  
  
end
