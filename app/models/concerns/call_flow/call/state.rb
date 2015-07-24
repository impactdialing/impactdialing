class CallFlow::Call::State
  include CallFlow::DialQueue::Util

  attr_reader :base_key, :object

private
  def key
    "#{base_key}:state"
  end

  def validate_base_key!
    base_key_parts = base_key.split ':'
    if base_key_parts.any?(&:blank?) or base_key_parts.size < 3
      raise CallFlow::Call::InvalidBaseKey, "#{self.class} requires a base key with 3 non-blank parts separated by colons."
    end
  end

public
  def initialize(base_key)
    @base_key = base_key
    validate_base_key!
  end

  def visited(state)
    redis.hset(key, state, Time.now.utc)

    if redis.ttl(key) < 0
      redis.expire(key, 1.day)
    end
  end

  def visited?(state)
    redis.hexists(key, state)
  end

  def not_visited?(state)
    not visited?(state)
  end
end

