class CallList::Stats
  attr_reader :record

  include CallFlow::DialQueue::Util

private
  def namespace
    klass = record.kind_of?(Campaign) ? Campaign : record.class
    "list:#{klass.to_s.underscore}:#{record.id}"
  end

  def initialize(record)
    @record = record
  end

  def key
    "#{namespace}:stats"
  end

  def reset(hkey, value)
    redis.hset(key, hkey, value)
  end

  def [](attribute)
    redis.hget(key, attribute).to_i
  end
end

