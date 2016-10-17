class RedisStatus
  def self.redis
    $redis_dialer_connection
  end

  def self.redis_key(campaign_id)
    "campaign:#{campaign_id}:status"
  end

  def self.set_state_changed_time(campaign_id, status, caller_session_id)
    $redis_dialer_connection.hset "campaign:#{campaign_id}:status", caller_session_id, {status: status, time: Time.now.to_s}.to_json
  end

  def self.state_time(campaign_id, caller_session_id)
    result = []
    time_status = $redis_dialer_connection.hget "campaign:#{campaign_id}:status", caller_session_id
    unless time_status.nil?
      element = JSON.parse(time_status)
      time_spent = Time.now - Time.parse(element['time'] || Time.now.to_s)
      result = [element['status'], seconds_fraction_to_time(time_spent)]
    end
    return result
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
    "#{hours.to_s.rjust(2, '0')}:#{mins.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
  end

  def self.count_by_status(campaign_id, *caller_session_ids)
    on_hold  = 0
    on_call  = 0
    wrap_up  = 0
    out      = ->{ [on_hold, on_call, wrap_up] }
    hkeys    = caller_session_ids.flatten

    if hkeys.empty?
      return out.call
    end

    elements = redis.hmget "campaign:#{campaign_id}:status", *hkeys

    elements.compact.each do |element|
      ele = JSON.parse(element)
      on_hold = on_hold + 1 if ele['status'] == 'On hold'
      on_call = on_call + 1 if ele['status'] == 'On call'
      wrap_up = wrap_up + 1 if ele['status'] == 'Wrap up'
    end

    return out.call
  end

  def self.on_hold_times(campaign_id, *caller_session_ids)
    hkeys = caller_session_ids.compact.flatten
    return [] if hkeys.empty?

    elements = redis.hmget redis_key(campaign_id), *hkeys
    elements.map do |element|
      next if element.nil?
      parsed_element = JSON.parse(element)
      next if parsed_element['status'] != 'On hold'

      parsed_time = Time.parse(parsed_element['time'])

      Time.now.to_i - parsed_time.to_i
    end.compact
  end
end
