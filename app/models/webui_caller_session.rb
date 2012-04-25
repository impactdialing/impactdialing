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
        event :pause_conf, :to => :connected
        
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
        response do |xml_builder, the_call|
          xml_builder.Say("Please enter your call results") 
          xml_builder.Pause("length" => 11)
          xml_builder.Redirect(flow_caller_url(caller, host: Settings.host, port: Settings.port, session_id:  id, event: "pause_conf"))
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
    
  end
  
  def dial(voter)
    attempt = create_call_attempt(voter)
    publish_calling_voter
    response = make_call(attempt,voter)    
    if response["TwilioResponse"]["RestException"]
      handle_failed_call(attempt)
      return
    end    
    attempt.update_attributes(:sid => response["TwilioResponse"]["Call"]["Sid"])
  end
  
  def create_call_attempt(voter)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt)
    attempt    
  end
  
  def make_call(attempt,voter)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    params = {'FallbackUrl' => TWILIO_ERROR, 'StatusCallback' => flow_call_url(attempt.call, host: Settings.host, port:  Settings.port, event: "call_ended"),'Timeout' => campaign.use_recordings? ? "30" : "15"}
    params.merge!({'IfMachine'=> 'Continue'}) if campaign.answering_machine_detect        
    Twilio::Call.make(self.campaign.caller_id, voter.Phone, flow_call_url(attempt.call, host: Settings.host, port: Settings.port, event: "incoming_call"),params)    
  end
  
  def handle_failed_call(attempt)
    Rails.logger.info "Exception when attempted to call #{voter.Phone} for campaign id:#{self.campaign_id}  Response: #{response["TwilioResponse"]["RestException"].inspect}"
    attempt.update_attributes(status: CallAttempt::Status::FAILED, wrapup_time: Time.now)
    voter.update_attributes(status: CallAttempt::Status::FAILED)
    update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil,:voter_in_progress => nil)
    next_voter = campaign.next_voter_in_dial_queue(voter.id)
    publish('call_could_not_connect',next_voter.nil? ? {} : next_voter.info)    
  end
  
  
  
end