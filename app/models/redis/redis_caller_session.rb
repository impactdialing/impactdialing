class RedisCallerSession

  def self.redis
    $redis_caller_session_uri_connection
  end

  ## active_transfer_*
  # todo: refactor active_transfer_* to own obj
  # todo: refactor RedisCallerSession & other redis classes
  #
  # active_transfer_* methods are for managing
  # the active_transfer flag which is useful
  # to determine which TwiML to render.
  #
  def self.active_transfer_key(session_key)
    "caller_sessions.#{session_key}.active_transfer"
  end

  def self.active_transfer(caller_session_key)
    redis.get(active_transfer_key(caller_session_key))
  end

  def self.active_transfer?(caller_session_key)
    on_off = active_transfer(caller_session_key)
    on_off.to_i > 0
  end

  def self.activate_transfer(caller_session_key)
    redis.set(active_transfer_key(caller_session_key), 1)
  end

  def self.deactivate_transfer(caller_session_key)
    redis.del(active_transfer_key(caller_session_key))
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