class ModeratorJob 
  include Sidekiq::Worker
  sidekiq_options :queue => :monitor_worker
  
  
   def self.perform(campaign_id, event, time_now) 
     redis = Redis.current
     time_refreshed = redis.hmget "moderator:#{campaign_id}", "timestamp"      
     return if time_now < time_refreshed[0].to_time
     pub_sub = MonitorPubSub.new  
     pub_sub.push_to_monitor_screen(campaign_id, event, time_now)
   end
end