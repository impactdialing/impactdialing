class RedisStatus
  
  def self.set_state_changed_time(campaign_id, status, caller_session_id)
    $redis_dialer_connection.hset "campaign:#{campaign_id}:status", caller_session_id, {status: status, time: Time.now.to_s}.to_json
  end
  
  def self.state_time(campaign_id, caller_session_id)
    time_status = $redis_dialer_connection.hget "campaign:#{campaign_id}:status", caller_session_id
    unless time_status.nil?
      element = JSON.parse(time_status)
      time_spent = Time.now - Time.parse(element['time'] || Time.now.to_s)    
      [element['status'], seconds_fraction_to_time(time_spent)]
    end
  end
  
  def self.delete_state(campaign_id, caller_session_id)
    $redis_dialer_connection.hdel "campaign:#{campaign_id}:status", caller_session_id    
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
  
  def self.count_by_status(campaign_id, *caller_session_ids)
    elements = $redis_dialer_connection.hmget "campaign:#{campaign_id}:status" , *caller_session_ids.flatten
    on_hold = 0
    on_call = 0
    wrap_up = 0
    elements.compact.each do |element|
     ele = JSON.parse(element)
     on_hold = on_hold + 1 if ele['status'] == 'On hold'
     on_call = on_call + 1 if ele['status'] == 'On call'
     wrap_up = wrap_up + 1 if ele['status'] == 'Wrap up'
   end
  [on_hold, on_call, wrap_up]
 end
  
end