class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  
  def switch_monitor_mode(session, type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => session.session_key})
    conference_sid = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']['Sid']
    
    if type == "breakin"
      Twilio::Conference.unmute_participant(conference_sid, call_sid)
    else
      Twilio::Conference.mute_participant(conference_sid, call_sid)
    end
  end
  
  def stop_monitoring(session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Conference.kick_participant(session.session_key, call_sid)
  end
  
end
