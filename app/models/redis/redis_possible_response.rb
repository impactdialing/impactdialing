class RedisPossibleResponse
  def self.redis
    $redis_question_pr_uri_connection
  end

  def self.key(question_id)
    "possible_response:#{question_id}"
  end

  def self.expire(script_id, ttl)
    redis.expire(key(script_id), ttl)
  end

  def self.persist_possible_response(question_id, possible_response)
    redis.lpush key(question_id), {id: question_id, keypad: possible_response.keypad, value: possible_response.value}.to_json
  end
  
  def self.possible_responses(question_id)
    possible_responses = redis.lrange key(question_id), 0, -1
    unless possible_responses.blank?
      possible_responses.collect {|x| JSON.parse(x)}      
    end
  end
  
  def self.clear_list(question_id)
    redis.del(key(question_id))
  end

  def self.cached?(question_id)
    redis.llen(key(question_id)) > 0
  end
end