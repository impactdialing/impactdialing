require 'digest/sha1'

class RedisQuestion
  def self.redis
    $redis_question_pr_uri_connection
  end

  def self.checksum_key(script_id)
    "question_list:script:#{script_id}:checksum"
  end

  def self.set_checksum(script_id, checksum, ttl)
    redis_connection_pool.with do |conn| 
      conn.set(checksum_key(script_id), checksum)
      conn.expire(checksum_key(script_id), ttl)
    end  

    # redis.set(checksum_key(script_id), checksum)
    # redis.expire(checksum_key(script_id), ttl)
  end

  def self.get_checksum(script_id)
    redis_connection_pool.with{|conn| conn.get(checksum_key(script_id))}
    # redis.get(checksum_key(script_id))
  end

  def self.key(script_id)
    "question_list:script:#{script_id}"
  end

  def self.expire(script_id, ttl)
    redis_connection_pool.with{|conn| conn.expire(key(script_id), ttl)}
    # redis.expire(key(script_id), ttl)
  end

  def self.persist_questions(script_id, question)
    redis_connection_pool.with{|conn| conn.lpush key(script_id), {id: question.id, question_text: question.text}.to_json}
    # redis.lpush key(script_id), {id: question.id, question_text: question.text}.to_json
  end
  
  def self.get_question_to_read(script_id, question_number)
    question = redis_connection_pool.with{|conn| conn.lindex key(script_id), question_number}
    # question = redis.lindex key(script_id), question_number 
    unless question.nil?
      JSON.parse(question)
    end
  end
  
  def self.more_questions_to_be_answered?(script_id, question_number)
    number_of_questions = redis_connection_pool.with{|conn| conn.llen key(script_id)}
    # number_of_questions = redis.llen key(script_id)
    number_of_questions > question_number.to_i
  end
  
  def self.clear_list(script_id)
    redis_connection_pool.with{|conn| conn.del(key(script_id))}
    # redis.del(key(script_id))
  end

  def self.cached?(script_id)
    redis_connection_pool.with{|conn| conn.llen(key(script_id)) > 0}
    # redis.llen(key(script_id)) > 0
  end
end
