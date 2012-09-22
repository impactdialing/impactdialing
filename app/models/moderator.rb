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
  
  def self.update_dials_in_progress(campaign)
    publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
  end
  
  def self.active_moderators(campaign)
    campaign.account.moderators.last_hour.active.select('session')
  end
  
  def self.update_dials_in_progress_sync(campaign)
    Moderator.active_moderators(campaign).each do|moderator|
      begin
        Pusher[moderator.session].trigger!('update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
      rescue Exception => e
        Rails.logger.error "Pusher exception: #{e}"    
      end
    end 
  end
  
  
  def self.caller_connected_to_campaign(caller, campaign, caller_session)
    return if campaign.account.moderators.active.empty?
    caller.email = caller.identity_name
    caller_info = caller.info
    data = caller_info.merge(:campaign_name => campaign.name, :session_id => caller_session.id, :campaign_fields => {:id => campaign.id, 
      :callers_logged_in => campaign.caller_sessions.on_call.size+1,
      :voters_count => campaign.voters_count("not called", false), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size },
      :campaign_ids => caller.account.campaigns.manual.active.collect{|c| c.id}, :campaign_names => caller.account.campaigns.manual.active.collect{|c| c.name},:current_campaign_id => campaign.id)
      publish_event(campaign, 'caller_session_started', data)
  end
  
  def self.publish_event(campaign, event, data)
    Moderator.active_moderators(campaign).each do |moderator|
      EM.run {
        deferrable = Pusher[moderator.session].trigger_async(event, data)
        deferrable.callback { 
          }
        deferrable.errback { |error|
        }
      }
    end 
  end
  
  
  
  def get_conference_id(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    conferences = Twilio::Conference.list({"FriendlyName" => caller_session.session_key})
    confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
    conference_sid = ""
    conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
  end
  
end
