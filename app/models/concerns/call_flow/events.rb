class CallFlow::Events
  attr_reader :session

  delegate :storage, to: :session

  def redis
    $redis_call_flow_connection
  end

  def key
    "call_flow:events:#{session.sid}"
  end

  def initialize(caller_session_call)
    @session = caller_session_call
  end

  def completed?(event_sequence)
    redis.getbit(key, event_sequence).to_i > 0
  end

  def completed(event_sequence)
    if redis.ttl(key) < 1
      redis.expire(key, 2.weeks)
    end
    redis.setbit(key, event_sequence, 1)
  end

  def generate_sequence
    storage.incrby('event_sequence', 1)
  end
end

