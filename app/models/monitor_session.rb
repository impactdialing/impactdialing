class MonitorSession
  
  def self.monitor_session(campaign_id)
    Redis::Set.new("monitor:#{campaign_id}", $redis_monitor_connection)    
  end
    
  def self.add_session(campaign_id)
    key = generate_session_key
    monitor_session(campaign_id).add(key)
    key        
  end
  
  def self.remove_session(campaign_id, session_key)
    monitor_session(campaign_id).delete(session_key)
  end
  
  def self.sessions(campaign_id)
    monitor_session(campaign_id).members
  end
  
  def self.generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
  
  def self.secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end
  
  
end