require 'resque-loner'

class CachePhonesOnlyScriptQuestions
  include Resque::Plugins::UniqueJob
  @queue = :persist_jobs

  def self.queue(script_id, action)
    Resque.enqueue(self, script_id, action)
  end

  def self.perform(script_id, action='update')
    script = Script.find script_id

    send("#{action}_cache", script)
  end

  def self._ttl
    6.hours
  end

  def self.seed_cache(script, ttl=nil)
    ttl ||= _ttl
    cache!(script, ttl) if cache_empty?(script.id)
  end

  def self.update_cache(script)
    cache!(script) unless cache_empty?(script.id)
  end

  def self.cache!(script, ttl=nil)
    redis.multi do
      RedisQuestion.clear_list(script.id)

      script.questions.reverse.each do|question|
        RedisQuestion.persist_questions(script.id, question.id, question.text)

        RedisPossibleResponse.clear_list(question.id)
        
        question.possible_responses.reverse.each do |possible_response|
          RedisPossibleResponse.persist_possible_response(question.id, possible_response.keypad, possible_response.value)
        end

        RedisPossibleResponse.expire(question.id, ttl) unless ttl.nil?
      end

      RedisQuestion.expire(script.id, ttl) unless ttl.nil?
    end
  end

  def self.cache_empty?(script_id)
    not RedisQuestion.cached?(script_id)
  end
end
