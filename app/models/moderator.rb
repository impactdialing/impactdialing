class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  
  def switch_monitor_mode(session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    if params[:type] == "breakin"
      Twilio.Conference.mute_participant(session.session_key, call_sid)
    else
      Twilio.Conference.unmute_participant(session.session_key, call_sid)
    end
  end
  
  def stop_monitoring(session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio.Conference.kick_participant(session.session_key, call_sid)
  end
  
end
