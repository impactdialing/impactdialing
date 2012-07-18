require 'redis'
class MonitorPubSub 
  
  def initialize
   @redis = Redis.current    
  end
  

  def push_to_monitor_screen
    @redis.psubscribe(:monitor_event ) do |on|
      on.pmessage do |pattern, event, message|     
        puts message
      end
   end
   
  end
  
end