class Moderator < ActiveRecord::Base
  belongs_to :caller_session
  belongs_to :account
  
  scope :active, :conditions => {:active => true}
  
  def switch_monitor_mode(session, type)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => session.session_key})
    confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
    conference_sid = ""
    conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
    
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
  
  def self.caller_connected_to_campaign(caller, campaign, caller_session)
    caller_info = caller.info
    data = caller_info.merge(:campaign_name => campaign.name, :session_id => caller_session.id, :campaign_fields => {:id => campaign.id, :callers_logged_in => campaign.caller_sessions.on_call.length+1,
       :voters_count => campaign.voters_count("not called", false).length, :path => Rails.application.routes.url_helpers.client_campaign_path(campaign) })
    caller.account.moderators.active.each {|moderator| Pusher[moderator.session].trigger('caller_session_started', data)}    
  end
  
  def self.publish_event(caller, event, data)
    caller.account.moderators.active.each {|moderator| Pusher[moderator.session].trigger(event, data)}
  end
  
end
