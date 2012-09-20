class Stream
  
  def self.add_to_stream(name, value)
    redis = RedisConnection.timeseries_connection
    redis.zadd(name, Time.now.to_i, value)
  end
end