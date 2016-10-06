class RedisPossibleResponse

  def self.redis
    Rails.logger.warn("Redis connection - RedisPossibleResponse")
    Redis.new
  end

  def self.redis_connection_pool    
    $redis_question_pr_uri_connection
  end

  def self.key(question_id)
    "possible_response:#{question_id}"
  end

  def self.expire(script_id, ttl)
    redis_connection_pool.with{|conn| conn.expire(key(script_id), ttl)}
    # redis.expire(key(script_id), ttl)
  end

  def self.persist_possible_response(question_id, possible_response)
    redis_connection_pool.with{|conn| conn.lpush key(question_id), {id: question_id, possible_response_id: possible_response.id, keypad: possible_response.keypad, value: possible_response.value}.to_json}
    # redis.lpush key(question_id), {id: question_id, possible_response_id: possible_response.id, keypad: possible_response.keypad, value: possible_response.value}.to_json
  end
  
  def self.possible_responses(question_id)
    possible_responses = redis.lrange key(question_id), 0, -1
    unless possible_responses.blank?
      possible_responses.collect {|x| JSON.parse(x)}      
    end
  end
  
  def self.clear_list(question_id)
    redis_connection_pool.with{|conn| conn.del(key(question_id))}
    # redis.del(key(question_id))
  end

  def self.cached?(question_id)
    redis_connection_pool.with{|conn| conn.llen(key(question_id)) > 0}
    # redis.llen(key(question_id)) > 0
  end
end
