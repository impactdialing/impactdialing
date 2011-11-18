class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  
  def switch_monitor_mode(session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    if params[:to_type] == "eavesdrop"
      Twilio.Conference.mute_participant(session.session_key, call_sid).response
    else
      Twilio.Conference.unmute_participant(session.session_key, call_sid).response
    end
  end
  
  def stop_monitor(session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio.Conference.kick_participant(session.session_key, call_sid).response
  end
  
end
