module CallTwiml
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def abandoned_twiml
      Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    def disconnected_twiml
      Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    def connected_twiml
      Twilio::TwiML::Response.new do |r|
        unless caller_session.nil? 
          r.Dial :hangupOnStar => 'false', :action => flow_call_url(self, :host => Settings.twilio_callback_host, event: "disconnect"), :record=> campaign.account.record_calls do |d|
            d.Conference caller_session.session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
          end
        else
          Twilio::TwiML::Response.new { |r| r.Hangup }.text
        end
      end.text
    end

    def call_answered_by_machine_twiml
      Twilio::TwiML::Response.new do |r|
        r.Play campaign.recording.file.url if campaign.use_recordings?
        r.Hangup      
      end.text
    end    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end
