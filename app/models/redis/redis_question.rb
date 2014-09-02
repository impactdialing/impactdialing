require 'digest/sha1'

class RedisQuestion
  def self.redis
    $redis_question_pr_uri_connection
  end

  def self.checksum_key(script_id)
    "question_list:script:#{script_id}:checksum"
  end

  def self.set_checksum(script_id, checksum, ttl)
    redis.set(checksum_key(script_id), checksum)
    redis.expire(checksum_key(script_id), ttl)
  end

  def self.get_checksum(script_id)
    redis.get(checksum_key(script_id))
  end

  def self.key(script_id)
    "question_list:script:#{script_id}"
  end

  def self.expire(script_id, ttl)
    redis.expire(key(script_id), ttl)
  end

  def self.persist_questions(script_id, question)
    redis.lpush key(script_id), {id: question.id, question_text: question.text}.to_json
  end
  
  def self.get_question_to_read(script_id, question_number)
    question = redis.lindex key(script_id), question_number 
    unless question.nil?
      JSON.parse(question)
    end
  end
  
  def self.more_questions_to_be_answered?(script_id, question_number)
    number_of_questions = redis.llen key(script_id)
    number_of_questions > question_number
  end
  
  def self.clear_list(script_id)
    redis.del(key(script_id))
  end

  def self.cached?(script_id)
    redis.llen(key(script_id)) > 0
  end
end
