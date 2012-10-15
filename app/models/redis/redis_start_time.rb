class RedisStartTime
  
  def self.set_state_changed_time(caller_session_id)
    $redis_dialer_connection.set "caller_session:#{caller_session_id}:start_time", Time.now.to_s
  end
  
  def self.time_in_state(caller_session_id)
    time = $redis_dialer_connection.get "caller_session:#{caller_session_id}:start_time"
    Time.now -    
  end
end