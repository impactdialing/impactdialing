require Rails.root.join("lib/redis_connection")

class MonitorJob 
  
  include Sidekiq::Worker
  sidekiq_options :queue => :monitor_worker
  
   def perform(campaign_id, event, time_now) 
     redis = RedisConnection.monitor_connection
     time_refreshed = redis.hmget "moderator:#{campaign_id}", "timestamp"      
     return if time_now.to_time < time_refreshed[0].to_time
     pub_sub = MonitorPubSub.new  
     pub_sub.push_to_monitor_screen(campaign_id, event, time_now)
   end
   
end