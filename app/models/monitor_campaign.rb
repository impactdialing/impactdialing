class MonitorCampaign
  include Redis::Objects
  
  
  def initialize(campaign_id, num_callers_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, 
    num_available, num_remaining)
    campaign = Campaign.find(campaign_id)
    monitor_campaign_hash = Redis::HashKey.new("monitor_campaign:#{campaign_id}", $redis_monitor_connection)
    monitor_campaign_hash.bulk_set({timestamp: Time.now, name: campaign.name, id: campaign.id})
    monitor_campaign_hash.delete("callers_logged_in")
    monitor_campaign_hash.delete("on_call")    
    monitor_campaign_hash.delete("on_hold")
    monitor_campaign_hash.delete("ringing_lines")    
    monitor_campaign_hash.delete("wrapup")
    monitor_campaign_hash.delete("live_lines")    
    monitor_campaign_hash.delete("available")
    monitor_campaign_hash.delete("remaining")    
    monitor_campaign_hash.incrby("callers_logged_in", num_callers_logged_in)    
    monitor_campaign_hash.incrby("on_call", num_on_call)        
    monitor_campaign_hash.incrby("on_hold", num_on_hold)    
    monitor_campaign_hash.incrby("ringing_lines", num_ringing_lines)        
    monitor_campaign_hash.incrby("wrapup",num_wrapup)    
    monitor_campaign_hash.incrby("live_lines", num_live_lines)        
    monitor_campaign_hash.incrby("available",num_available)    
    monitor_campaign_hash.incrby("remaining", num_remaining)        

    $redis_monitor_connection.zadd("monitoring", Time.now.to_i,  "monitor_campaign:#{campaign_id}")
  end
  
  def self.monitor_campaign(campaign_id)
    Redis::HashKey.new("monitor_campaign:#{campaign_id}", $redis_monitor_connection)    
  end   
  
  ['callers_logged_in', 'on_call', 'on_hold', 'wrapup', 'live_lines', 'ringing_lines', 'available', 'remaining' ].each do |value|
    define_singleton_method("increment_#{value}") do |campaign_id, num|
      monitor_campaign(campaign_id).incrby(value, num)
    end
    
    define_singleton_method("decrement_#{value}") do |campaign_id, num|
      monitor_campaign(campaign_id).incrby(value, -num)
    end
    
    define_singleton_method("#{value}") do |campaign_id|
      monitor_campaign(campaign_id).fetch(value)
    end
  end
  
  def self.name(campaign_id)
    monitor_campaign(campaign_id).fetch('name')
  end
  
  def self.add_caller_status(caller_id, status)
    monitor_campaign(campaign_id).store("caller:#{caller_id}", status)
  end
  
  def self.remove_caller(caller_id)
    monitor_campaign(campaign_id).delete("caller:#{caller_id}")
  end
  
  def self.campaign_overview_info(campaign)
    num_logged_in = campaign.caller_sessions.on_call.size
    num_on_call = campaign.caller_sessions.not_available.size
    num_wrapup = RedisCampaignCall.wrapup(campaign.id).length
    num_on_hold = campaign.caller_sessions.available.size
    num_live_lines = RedisCampaignCall.inprogress(campaign.id).length
    num_ringing_lines = RedisCampaignCall.ringing(campaign.id).length
    num_remaining = campaign.all_voters.by_status('not called').count
    num_available = num_voter_available(campaign) + num_remaining
    [num_logged_in, num_on_call, num_wrapup, num_on_hold, num_live_lines, num_ringing_lines, num_available, num_remaining]
  end
  
  def self.num_voter_available(campaign)
    voters_available_for_retry = campaign.all_voters.enabled.avialable_to_be_retried(campaign.recycle_rate).count
    scheduled_for_now = campaign.all_voters.scheduled.count
    abandoned_count = campaign.all_voters.by_status(CallAttempt::Status::ABANDONED).count
    sanitize_dials(voters_available_for_retry + scheduled_for_now + abandoned_count)
  end
  
  def self.sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
  
  def self.get_conference_id(caller_session)
     Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
     conferences = Twilio::Conference.list({"FriendlyName" => caller_session.session_key})
     confs = conferences.parsed_response['TwilioResponse']['Conferences']['Conference']
     conference_sid = ""
     conference_sid = confs.class == Array ? confs.last['Sid'] : confs['Sid']
  end
  
  def self.switch_monitor_mode(caller_session, type, monitor_session)
    conference_sid = get_conference_id(caller_session)
    call_sid = MonitorConference.call_sid(monitor_session)
    if type == "breakin"
      Twilio::Conference.unmute_participant(conference_sid, call_sid)
    else
      Twilio::Conference.mute_participant(conference_sid, call_sid)
    end
  end
  
   
end