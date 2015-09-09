module CallList::Stats
  include CallFlow::DialQueue::Util

  def redis_namespace
    klass = self.kind_of?(Campaign) ? Campaign : self.class
    "list:#{klass.to_s.underscore}:#{self.id}"
  end

  def list_stats_key
    "#{redis_namespace}:stats"
  end

  def list_stats
    HashWithIndifferentAccess.new(redis.hgetall(list_stats_key))
  end

  def list_stats_reset(key, value)
    redis.hset(list_stats_key, key, value)
  end
end

