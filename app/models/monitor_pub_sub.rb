require 'redis'
class MonitorPubSub 
  
  def initialize
   @redis = Redis.current    
  end
  

  def push_to_monitor_screen(campaign_id, caller_session_id, event, time_now)
    campaign = Campaign.find(campaign_id)
    caller_session = CallerSession.find_by_id(caller_session_id)
    pub_sub = MonitorPubSub.new
    pub_sub.send(event)    
    Moderator.active_moderators(campaign).each do|moderator|
      begin
        Pusher[moderator.session].trigger!('update_campaign_info', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
      rescue Exception => e
        Rails.logger.error "Pusher exception: #{e}"    
      end
    end         
  end
  
end