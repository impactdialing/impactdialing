module CallerTwiml
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def paused_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("Please enter your call results") 
        r.Pause("length" => 600)      
      end.text      
    end

    def disconnected_twiml
      Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    def connected_twiml
      Twilio::TwiML::Response.new do |r|
        r.Dial(:hangupOnStar => true, :action => flow_caller_url(caller, session_id:  id, event: "pause_conf", host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port)) do
          r.Conference(session_key, startConferenceOnEnter: false, endConferenceOnExit:  true, beep: true, waitUrl: HOLD_MUSIC_URL, waitMethod:  'GET')
        end        
      end.text
    end

    def call_answered_by_machine_twiml
      Twilio::TwiML::Response.new do |r|
        r.Play campaign.recording.file.url if campaign.use_recordings?
        r.Hangup      
      end.text
    end   
    
    def subscription_limit_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.")
        r.Hangup          
      end.text      
    end
    
    def account_has_no_funds_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say("There are no funds available in the account.  Please visit the billing area of the website to add funds to your account.")
        r.Hangup          
      end.text      
    end
    
    
    def account_not_activated_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say "Your account has insufficent funds"
        r.Hangup
      end.text            
    end
    
    def time_period_exceeded_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:campaign_time_period_exceed, :start_time => campaign.start_time.hour <= 12 ? "#{campaign.start_time.hour} AM" : "#{campaign.start_time.hour-12} PM", :end_time => campaign.end_time.hour <= 12 ? "#{campaign.end_time.hour} AM" : "#{campaign.end_time.hour-12} PM")
        r.Hangup
      end.text                  
    end
    
    def conference_ended_twiml
      Twilio::TwiML::Response.new do |r|
        r.Hangup
      end.text                        
    end
    
    def campaign_out_of_phone_numbers_twiml
      Twilio::TwiML::Response.new do |r|
        r.Say I18n.t(:campaign_out_of_phone_numbers)
        r.Hangup
      end.text                              
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end
