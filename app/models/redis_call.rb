class RedisCall
  
  def store_call_details(params)
    Resque.redis.rpush("impactdialing_calls", params)
  end
end