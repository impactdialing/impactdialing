class ModeratorJob 
  include Sidekiq::Worker
  sidekiq_options :queue => :monitor_worker
  
  
   def self.perform(campaign_id, caller_session_id, event, time_now) 
     redis = Redis.current
     redis.hmget "moderator:#{campaign_id}", timestamp      
     return if time_now < redis.hmget "moderator:#{campaign_id}", timestamp
     pub_sub = MonitorPubSub.new  
     pub_sub.push_to_monitor_screen(campaign_id, event, time_now)
   end
end