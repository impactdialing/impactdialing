class MonitorConference
  
  def self.monitor_conference(monitor_session)
    Redis::HashKey.new("monitor:#{monitor_session}", $redis_dialer_connection)
  end
  
  def self.join_conference(monitor_session, caller_session, call_sid)
    hash = monitor_conference(monitor_session)
    hash.store('caller_session', caller_session)
    hash.store('call_sid', call_sid)        
  end
  
  def self.call_sid(monitor_session)
    monitor_conference(monitor_session).fetch("call_sid")
  end
  
end