require 'redis'
require Rails.root.join("lib/redis_connection")
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class MonitorPubSub 
  
  def initialize
   @redis = RedisConnection.monitor_connection    
  end
  

  def push_to_monitor_screen(campaign_id, event, time_now)
    campaign = Campaign.find(campaign_id)
    moderator_event = MonitorEvent.new
    moderator_event.send(event, campaign)
    EM.synchrony {
      MonitorSession.sessions(campaign_id).each do|monitor_session|
        begin
          campaign_info = @redis.hgetall "moderator:#{campaign.id}"
          Pusher[monitor_session].trigger_async('update_campaign_info',campaign_info )
        rescue Exception => e
          Rails.logger.error "Pusher exception: #{e}"    
        end
      end         
    }
  end
  
end