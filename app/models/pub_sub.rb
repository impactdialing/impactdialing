class PubSub
  
  def initialise
    @redis = Redis.connect(REDIS)
  end
  
  def subscribe(session_key)    
    @redis.subscribe(session_key) do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end

      on.message do |channel, message|
        Pusher[channel].trigger(event, data.merge!(:dialer => dialer_type))
        puts "##{channel}: #{message}"
        @redis.unsubscribe if message == "exit"
      end

      on.unsubscribe do |channel, subscriptions|
        puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
      end
    end    
  end
  

end