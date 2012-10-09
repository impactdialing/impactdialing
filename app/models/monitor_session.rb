class MonitorSession
  
  def self.monitor_session(campaign_id)
    Redis::SortedSet.new("monitor:#{campaign_id}", $redis_dialer_connection)    
  end
    
  def self.add_session(campaign_id)
    key = generate_session_key
    monitor_session(campaign_id).add(key, Time.now.to_i)
    key        
  end
  
  def self.remove_session(campaign_id, session_key)
    monitor_session(campaign_id).delete(session_key)
  end
  
  def self.sessions(campaign_id)
    monitor_session(campaign_id).members
  end
  
  def self.sessions_last_hour(campaign_id)
    monitor_session(campaign_id).rangebyscore((Time.now - 60.minutes).to_i, Time.now.to_i)
  end
  
  
  def self.generate_session_key
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
  
  def self.secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end
  
  
end