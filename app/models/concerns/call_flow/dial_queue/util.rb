module CallFlow::DialQueue::Util
  def redis
    $redis_call_flow_connection
  end

  def expire(key, ttl)
    if redis.ttl(key) < 0
      redis.expire(key, ttl)
    end
  end
end
