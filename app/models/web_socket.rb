class WebSocket
  
  def subscribe(session_key)
    redis = Redis.connect(REDIS)
    redis.subscribe(session_key) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end

      on.message do |channel, message|
        puts "##{channel}: #{message}"
        redis.unsubscribe if message == "exit"
      end

      on.unsubscribe do |channel, subscriptions|
        puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
      end
    end    
  end
  
  
  def self.publish_for_caller(session_key, event, data, dialer_type, web_ui)
    return unless web_ui
    Pusher[session_key].trigger(event, data.merge!(:dialer => dialer_type))
  end
  
  def self.publish_for_moderator(session_key, event, data)
    Pusher[session_key].trigger_async(event, data)
  end
  
end