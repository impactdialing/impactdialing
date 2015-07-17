module List::Stats
  include CallFlow::DialQueue::Util

  def redis_namespace
    klass = self.kind_of? Campaign ? Campaign : self.class
    "list:#{klass.to_s.underscore}:#{self.id}"
  end

  def list_stats_key
    "#{redis_namespace}:stats"
  end

  def custom_id_set_key
    "#{redis_namespace}:custom_ids"
  end

  def list_stats
    @list_stats ||= HashWithIndifferentAccess.new(redis.hgetall(list_stats_key))
  end

  def list_custom_ids
    @list_custom_ids ||= redis.zrange(custom_id_set_key, 0, -1)
  end
end

