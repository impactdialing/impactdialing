class WebuiCallerSession < CallerSession  
  include Rails.application.routes.url_helpers
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :connected
      end 
            
      state :connected do  
              
        before(:always) { publish_start_calling; start_conference }
        after(:always) { publish_caller_conference_started }
        event :pause_conf, :to => :disconnected, :if => :disconnected?
        event :pause_conf, :to => :paused, :if => :call_not_wrapped_up?
        event :start_conf, :to => :connected
        event :stop_calling, :to=> :stopped
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, session_id:  id, event: "pause_conf", host: Settings.host, port:  Settings.port)) do
            xml_builder.Conference(session_key, startConferenceOnEnter: false, endConferenceOnExit:  true, beep: true, waitUrl: hold_call_url(host: Settings.host, port: Settings.port, version: HOLD_VERSION), waitMethod:  'GET')        
          end                              
        end
      end
      
      state :disconnected do        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end
      
      state :paused do        
        event :stop_calling, :to=> :stopped
        event :start_conf, :to => :connected
        
        response do |xml_builder, the_call|
          xml_builder.Say("Please enter your call results") 
          xml_builder.Pause("length" => 60)
        end        
      end
      
      state :stopped do
        before(:always) { end_running_call }        
      end
      
      
  end
  
  def call_not_wrapped_up?
    attempt_in_progress.not_wrapped_up?
  end
  
  def start_conference    
    reassign_caller_session_to_campaign if caller_reassigned_to_another_campaign?
    begin
      update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    rescue ActiveRecord::StaleObjectError
      # end conf
    end
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
  
  
  def publish_async(event, data)
    EM.run {
      deferrable = Pusher[session_key].trigger_async(event, data.merge!(:dialer => campaign.type))
      deferrable.callback { 
        }
      deferrable.errback { |error|
      }
    }
       
  end
  
  def publish_sync(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  
  
  
  
end