class ModeratorSession
    
  def self.add_session(campaign_id)
    key = generate_session_key
    redis = RedisConnection.monitor_connection
    redis.sadd("monitor:#{campaign_id}", key)
    key        
  end
  
  def self.remove_session(campaign_id, session_key)
    redis = RedisConnection.monitor_connection
    redis.srem("monitor:#{campaign_id}", session_key)        
  end
  
  def self.sessions(campaign_id)
    redis = RedisConnection.monitor_connection        
    redis.smembers("monitor:#{campaign_id}")    
  end
  
  def self.generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
  
  def self.secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end
  
  
end