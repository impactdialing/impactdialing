class RedisCallerSession

  def self.redis
    $redis_caller_session_uri_connection
  end

  def self.set_request_params(caller_session_id, options)
    redis.set "caller_session_flow:#{caller_session_id}", options.to_json
  end

  def self.delete(caller_session_id)
    redis.del "caller_session_flow:#{caller_session_id}"
  end

  def self.get_request_params(caller_session_id)
    redis.get "caller_session_flow:#{caller_session_id}"
  end

  def self.digit(caller_session_id)
    data = redis.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["digit"]
  end

  def self.question_id(caller_session_id)
    data = redis.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["question_id"]
  end

  def self.question_number(caller_session_id)
    data = redis.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["question_number"]
  end

  def self.set_datacentre(caller_session_id, caller_dc)
    redis.set "caller_dc:#{caller_session_id}", caller_dc
  end

  def self.datacentre(caller_session_id)
    redis.get "caller_dc:#{caller_session_id}"
  end

  def self.remove_datacentre(caller_session_id)
    redis.del "caller_dc:#{caller_session_id}"
  end

  def self.add_phantom_callers(caller_session_id)
    redis.lpush "phantom_callers", caller_session_id
  end

  def self.phantom_callers
    redis.lrange "phantom_callers", 0, -1
  end

  def self.remove_phantom_caller(caller_session_id)
    redis.del "phantom_callers", caller_session_id
  end
end
