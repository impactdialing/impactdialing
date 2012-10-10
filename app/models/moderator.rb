class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  belongs_to :account
  scope :active, :conditions => {:active => true}
  scope :last_hour, :conditions => ["created_at > ?",1.hours.ago]

  def switch_monitor_mode(caller_session, type)
    conference_sid = get_conference_id(caller_session)
    if type == "breakin"
      Twilio::Conference.unmute_participant(conference_sid, call_sid)
    else
      Twilio::Conference.mute_participant(conference_sid, call_sid)
    end
  end
    
  def stop_monitoring(caller_session)
    conference_sid = get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Conference.kick_participant(conference_sid, call_sid)
  end
  
  def self.active_moderators(campaign)
    campaign.account.moderators.last_hour.active.select('session')
  end

  def get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => caller_session.session_key})
    confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
    confs.class == Array ? confs.last['Sid'] : confs['Sid']
  end

end
