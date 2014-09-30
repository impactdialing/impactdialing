module CallFlow::DialQueue::Util
private
  def redis
    $redis_call_flow_connection
  end

  def expire(key, &block)
    set_expire = (not redis.exists(key))
    out        = yield

    if set_expire
      # expire this key at 23:59 tonight in the appropriate time zone
      today       = Date.today
      # campaign.end_time only stores the hour
      expire_time = Time.mktime(today.year, today.month, today.day, campaign.end_time.hour, 10)
      redis.expireat key, expire_time.in_time_zone(campaign.time_zone).end_of_day.to_i
    end

    return out
  end

public
  def clear
    redis.multi do
      keys.each do |key|
        redis.del key
      end
    end
  end
end