module CallTwiml

  module ClassMethods
  end

  module InstanceMethods

    def abandoned_twiml
      hangup_twiml
    end

    def disconnected_twiml
      hangup_twiml
    end

    def connected_twiml
      Twilio::TwiML::Response.new do |r|
        unless caller_session.nil?
          r.Dial :hangupOnStar => 'false', :action => disconnected_call_url(self, :host => DataCentre.call_back_host(data_centre), :protocol => "http://"), :record=> campaign.account.record_calls do |d|
            d.Conference caller_session.session_key, :waitUrl => HOLD_MUSIC_URL, :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true
          end
        else
          hangup_twiml
        end
      end.text
    end

    def play_message_twiml
      Twilio::TwiML::Response.new do |r|
        r.Play campaign.recording.file.url
        r.Hangup
      end.text
    end

    def call_ended_twiml
      hangup_twiml
    end

    def hangup_twiml
      Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
