##
# Class for caching list of dialed voters
class CallFlow::DialQueue::Dialed
  attr_reader :campaign

private
  def redis
    $redis_call_flow_connection
  end

  def keys
    {
      dialed: "dial_queue:dialed:#{campaign.id}"
    }
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
  def initialize(campaign)
    @campaign = campaign
  end

  def household_dialed(phone_number, call_time)
    expire keys[:dialed] do
      redis.hset keys[:dialed], phone_number, call_time
    end
  end

  def filter(voters)
    return voters if voters.empty?

    phone_numbers = voters.map{|v| v['phone']}
    call_times    = redis.hmget keys[:dialed], phone_numbers

    call_times.each_with_index do |call_time, i|
      next if call_time.nil?

      if call_time > campaign.recycle_rate.hours.ago
        voters[i] = nil
      end
    end
    
    voters.compact
  end

  def size
    # redis.llen keys[:dialed]
  end

  def peak(list=:dialed)
    # redis.lrange keys[list], 0, -1
  end

  def last
    # redis.lindex keys[:dialed], 0
  end

  def clear
    redis.multi do
      redis.del keys[:dialed]
    end
  end
end
