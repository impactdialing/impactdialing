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
    "conferences.#{session_key}.party_count"
  end

  def self._active_transfer_session_key(caller_session_key)
    "transfer_session_keys.#{caller_session_key}"
  end

  def self.active_transfer_session_key(caller_session_key)
    redis.get(_active_transfer_session_key(caller_session_key))
  end

  def self.add_active_transfer_session_key(caller_session_key, transfer_session_key)
    redis.set(_active_transfer_session_key(caller_session_key), transfer_session_key)
  end

  def self.remove_active_transfer_session_key(caller_session_key)
    redis.del(_active_transfer_session_key(caller_session_key))
  end

  def self.party_count(session_key)
    n = redis.get(active_transfer_key(session_key)).to_i
    Rails.logger.debug "DoublePause: RedisCallerSession.party_count(#{session_key}) => #{n}"
    n
  end

  def self.after_pause(caller_session_key, from_transfer_session_key)
    # Rails.logger.debug "DoublePause: RedisCallerSession.after_pause(#{caller_session_key})"
    transfer_session_key = active_transfer_session_key(caller_session_key)
    if party_count(transfer_session_key) == -1
      add_party(transfer_session_key) # incr count to 0 to indicate transfer has started
    end
    if from_transfer_session_key.present? and party_count(from_transfer_session_key) > 0
      # remove_party(transfer_session_key)
      remove_party(from_transfer_session_key)
    end
  end

  def self.pause?(caller_session_key, from_transfer_session_key)
    transfer_session_key = active_transfer_session_key(caller_session_key)

    n = party_count(transfer_session_key)
    if from_transfer_session_key.present?
      if transfer_session_key != from_transfer_session_key
        return false
      end
    end
    n.zero?
  end

  def self.add_party(session_key)
    Rails.logger.debug "DoublePause: RedisCallerSession.add_party(#{session_key})"
    if session_key.nil?
      Rails.logger.debug "DoublePause: RedisCallerSession.add_party - session_key is nil"
      remove_party_count(session_key)
      return
    end
    redis.incr(active_transfer_key(session_key))
  end

  def self.remove_party(session_key)
    Rails.logger.debug "DoublePause: RedisCallerSession.remove_party(#{session_key}) PartyCount: #{party_count(session_key)}"
    if session_key.nil?
      Rails.logger.debug "DoublePause: RedisCallerSession.remove_party - session_key is nil"
      remove_party_count(session_key)
      return
    end
    redis.decr(active_transfer_key(session_key))
    Rails.logger.debug "DoublePause: RedisCallerSession.remove_party(#{session_key}) PartyCount: #{party_count(session_key)}"
    if party_count(session_key) == 0
      remove_party_count(session_key)
    end
  end

  def self.remove_party_count(session_key)
    Rails.logger.debug "DoublePause: RedisCallerSession.remove_party_count(#{session_key})"
    redis.del(active_transfer_key(session_key))
  end

  def self.activate_transfer(caller_session_key, transfer_session_key)
    if caller_session_key.nil? or transfer_session_key.nil?
      return
    end
    add_active_transfer_session_key(caller_session_key, transfer_session_key)
    remove_party(transfer_session_key)
  end

  def self.deactivate_transfer(caller_session_key)
    Rails.logger.debug "DoublePause: RedisCallerSession.activate_transfer(#{caller_session_key})"
    transfer_session_key = active_transfer_session_key(caller_session_key)
    remove_party_count(transfer_session_key)
    remove_active_transfer_session_key(caller_session_key)
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