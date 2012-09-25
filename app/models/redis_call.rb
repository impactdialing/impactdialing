class RedisCall
  
  def self.store_call_details(params)
    puts params
    Resque.redis.rpush("impactdialing_calls", params)
  end
end