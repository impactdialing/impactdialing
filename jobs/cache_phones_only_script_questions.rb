require 'digest/sha1'
require 'resque-loner'
require 'librato_resque'

##
# Cache survey scripts, questions, possible responses to redis from relational database.
# This job is queued when a phones-only caller enters the correct pin.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class CachePhonesOnlyScriptQuestions
  include Resque::Plugins::UniqueJob
  extend LibratoResque
  
  @queue = :persist_jobs

  def self.add_to_queue(script_id, action)
    Resque.enqueue(self, script_id, action)
  end

  def self.perform(script_id, action='update')
    script  = Script.find script_id
    send("#{action}_cache", script)
  end

  def self._ttl
    6.hours
  end

  def self.sum(content)
    Digest::SHA1.hexdigest(content)
  end

  def self.seed_cache(script, ttl=nil)
    ttl ||= _ttl
    cache!(script, ttl) if cache_empty?(script.id)
  end

  def self.update_cache(script)
    cache!(script) unless cache_empty?(script.id)
  end

  def self.cache!(script, ttl=nil)
    content            = ''
    questions          = script.questions.reverse
    possible_responses = questions.map(&:possible_responses).flatten.reverse

    content = questions.map{|question| "#{question.id}:#{question.text}"}.join(';')
    content += possible_responses.map{|possible_response| "#{possible_response.id}:#{possible_response.keypad}:#{possible_response.value}"}.join(';')

    current_hash = sum(content)
    cached_hash  = RedisQuestion.get_checksum(script.id)

    return false if current_hash == cached_hash

    redis.multi do
      RedisQuestion.clear_list(script.id)

      script.questions.reverse.each do|question|
        RedisQuestion.persist_questions(script.id, question)

        RedisPossibleResponse.clear_list(question.id)
        
        question.possible_responses.reverse.each do |possible_response|
          RedisPossibleResponse.persist_possible_response(question.id, possible_response)
        end

        RedisPossibleResponse.expire(question.id, ttl) unless ttl.nil?
      end

      RedisQuestion.expire(script.id, ttl) unless ttl.nil?
      RedisQuestion.set_checksum(script.id, current_hash, (ttl || _ttl))
    end
  end

  def self.cache_empty?(script_id)
    not RedisQuestion.cached?(script_id)
  end
end
