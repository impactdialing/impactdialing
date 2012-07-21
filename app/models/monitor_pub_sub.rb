require 'redis'
require Rails.root.join("lib/redis_connection")
class MonitorPubSub 
  
  def initialize
   @redis = RedisConnection.monitor_connection    
  end
  

  def push_to_monitor_screen(campaign_id, event, time_now)
    campaign = Campaign.find(campaign_id)
    moderator_event = ModeratorEvent.new
    moderator_event.send(event, campaign)    
    Moderator.active_moderators(campaign).each do|moderator|
      begin
        campaign_info = @redis.hgetall "moderator:#{campaign.id}"
        Pusher[moderator.session].trigger_async('update_campaign_info',campaign_info )
      rescue Exception => e
        Rails.logger.error "Pusher exception: #{e}"    
      end
    end         
  end
  
end