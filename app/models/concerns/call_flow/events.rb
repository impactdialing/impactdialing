class CallFlow::Events
  attr_reader :session

  delegate :storage, to: :session
  delegate :expire, to: :session
  delegate :redis_expiry, to: :session
  delegate :redis, to: :session

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
    redis.setbit(key, event_sequence, 1)
    expire(key, redis_expiry)
  end

  def generate_sequence
    storage.incrby('event_sequence', 1)
  end
end

