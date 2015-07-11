module List::Stats
  include CallFlow::DialQueue::Util

  def list_stats_key
    klass = self.kind_of? Campaign ? Campaign : self.class
    "list:#{klass.to_s.underscore}:#{self.id}:stats"
  end

  def list_stats
    @counts ||= HashWithIndifferentAccess.new(redis.hgetall(list_stats_key))
  end
end
