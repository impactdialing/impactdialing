class WebuiCallerSession < CallerSession  
  include Rails.application.routes.url_helpers
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :connected
      end 
      
      
            
      state :connected do                
        before(:always) { start_conference; publish_start_calling }
        after(:success) { enqueue_call_flow(CallerPusherJob, [self.id,  "publish_caller_conference_started"]) }
        event :pause_conf, :to => :paused, :if => :call_not_wrapped_up?
        event :start_conf, :to => :connected
        event :run_ot_of_phone_numbers, :to=> :campaign_out_of_phone_numbers        
        event :stop_calling, :to=> :stopped
        
        response do |xml_builder, the_call|
          xml_builder.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, session_id:  id, event: "pause_conf", host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port)) do
            xml_builder.Conference(session_key, startConferenceOnEnter: false, endConferenceOnExit:  true, beep: true, waitUrl: HOLD_MUSIC_URL, waitMethod:  'GET')        
          end                              
        end
      end
      
      state :disconnected do        
        response do |xml_builder, the_call|
          xml_builder.Hangup
        end
      end
      
      
      state :paused do        
        event :start_conf, :to => :account_has_no_funds, :if => :funds_not_available?
        event :start_conf, :to => :time_period_exceeded, :if => :time_period_exceeded?   
        event :start_conf, :to => :connected
        event :stop_calling, :to=> :stopped
        
        response do |xml_builder, the_call|
          xml_builder.Say("Please enter your call results") 
          xml_builder.Pause("length" => 600)
        end        
      end
      
      state :stopped do
        before(:always) { end_running_call }        
      end
      
      
  end
  
  
  
  def call_not_wrapped_up?  
    attempt_in_progress.try(:connecttime) != nil &&  attempt_in_progress.try(:not_wrapped_up?)  
  end
  
  def publish_sync(event, data)
    Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
  end
  
  def call_status
    status = "On hold"
    if state == 'connected'
      if Campaign.predictive_campaign?(campaign.type) && !self.available_for_call
        status = "On call"
      elsif Campaign.preview_power_campaign?(campaign.type) && !attempt_in_progress.try(:connecttime).nil?
        status = "On call"
      end
    elsif state == 'paused'
       status = "Wrap up"
    else
      status = "On hold"
    end
    status
  end

end