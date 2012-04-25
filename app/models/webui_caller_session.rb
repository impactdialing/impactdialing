class WebuiCallerSession < CallerSession  
  include Rails.application.routes.url_helpers
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :connected
      end 
            
      state :connected do        
        before(:always) { start_conference }
        after(:always) { publish_caller_conference_started }
        event :pause_conf, :to => :disconnected, :if => :disconnected?
        event :pause_conf, :to => :paused, :if => :call_not_wrapped_up?
        event :pause_conf, :to => :connected
        
        response do |xml_builder, the_call|
          xml_builder.dial(:hangupOnStar => true, :action => flow_caller_url(caller, session_id:  id, event: "pause_conf", host: Settings.host, port:  Settings.port)) do
            xml_builder.conference(session_key, startConferenceOnEnter: false, endConferenceOnExit:  true, beep: true, waitUrl: hold_call_url(host: Settings.host, port: Settings.port, version: HOLD_VERSION), waitMethod:  'GET')        
          end                              
        end
      end
      
      state :disconnected do        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end
      
      state :paused do        
        response do |xml_builder, the_call|
          xml_builder.Say("Please enter your call results") 
          xml_builder.Pause("length" => 11)
          xml_builder.Redirect(pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => id))
        end        
      end
      
      state :stopped do
        before(:always) { end_running_call }        
      end
      
      
  end
  
  def call_not_wrapped_up?
    !voter_in_progress.nil?    
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
      self.update_attributes(:on_call => false, :available_for_call => false, :endtime => Time.now)
    rescue ActiveRecord::StaleObjectError
      self.reload
      self.end_running_call
    end      
    debit
    
    # Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
    #   :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})
    # self.publish("caller_disconnected", {source: "end_running_call"})
  end
  
  
end