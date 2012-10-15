class RedisStartTime
  
  def self.set_state_changed_time(caller_session_id)
    $redis_dialer_connection.set "caller_session:#{caller_session_id}:start_time", Time.now.to_s
  end
  
  def self.time_in_state(caller_session_id)
    time = $redis_dialer_connection.get "caller_session:#{caller_session_id}:start_time"
    puts "start_time"
    puts time
    time_spent = Time.now - Time.parse(time || Time.now.to_s)    
    seconds_fraction_to_time(time_spent)
  end
  
  def self.seconds_fraction_to_time(time_difference)
    days = hours = mins = 0
    mins = (time_difference / 60).to_i
    seconds = (time_difference % 60 ).to_i
    hours = (mins / 60).to_i
    mins = (mins % 60).to_i
    hours = (hours % 24).to_i
    "#{hours}:#{mins}:#{seconds}"
  end
end