module CallFlow::DialQueue::Util
  def redis
    Redis.new
  end

  def redis_connection_pool
    $redis_call_flow_connection
  end  

  def expire(key, ttl)
    redis_connection_pool.with do |conn|
      if conn.ttl(key) < 0
        conn.expire(key, ttl)
      end      
    end

  end
end
