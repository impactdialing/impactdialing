require 'resque-loner'
require 'librato_resque'

##
# Run periodically to persist answer data from phones-only callers.
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
# - 1 failure (WARNING: Exception rescued)
# - stops reporting for 5 minutes
#
class PersistPhonesOnlyAnswers
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :persist_jobs

  def self.keys
    RedisPhonesOnlyAnswer.keys
  end

  def self.redis
    $redis_phones_ans_uri_connection
  end

  def self.perform
    answers                     = []
    updated_voters              = []
    iterations_completed        = 0
    iterations_partial_data     = 0
    iterations_missing_response = 0

    4000.times do
      raw_data = redis.rpoplpush keys[:master], keys[:pending]

      break if raw_data.nil?

      answer_data = JSON.parse(raw_data)
      answer      = nil

      if partial_data?(answer_data)
        iterations_partial_data += 1
        partial_data!(raw_data)
        next
      end

      if (index = updated_voters.index{|v| v.id == answer_data['voter_id']})
        voter = updated_voters[index]
      else
        voter = Voter.find(answer_data['voter_id'])
      end

      caller_session    = CallerSession.find(answer_data['caller_session_id'])
      question          = Question.find(answer_data['question_id'])
      possible_response = question.possible_responses.where({
        :keypad => answer_data['digit']
      }).first
      
      if possible_response.present?
        answers << Answer.new({
          question:          question,
          possible_response: possible_response,
          campaign:          voter.campaign,
          caller:            caller_session.caller,
          call_attempt_id:   voter.household.last_call_attempt.id,
          voter_id:          voter.id
        })
        
        if index
          voter.update_call_back_incrementally(possible_response, false)
          updated_voters[index] = voter
        else
          voter.update_call_back_incrementally(possible_response, true)
          updated_voters << voter
        end

        iterations_completed += 1
      else
        # response most likely missing due to mis-entered digit
        partial_data!(raw_data)
        iterations_missing_response += 1
      end
    end

    ImpactPlatform::Metrics.sample('persistence.iterations.completed', iterations_completed, source)
    ImpactPlatform::Metrics.sample('persistence.iterations.missing_response', iterations_missing_response, source)
    ImpactPlatform::Metrics.sample('persistence.iterations.partial_data', iterations_partial_data, source)

    Answer.import answers
    Voter.import updated_voters, on_duplicate_key_update: [:call_back, :status, :updated_at]
  end

  def self.partial_data!(raw_data)
    redis.lpop keys[:pending]
    redis.rpush keys[:partial], raw_data
  end

  def self.partial_data?(data)
    data['voter_id'].blank? or data['caller_session_id'].blank? or
    data['question_id'].blank? or data['digit'].blank? or
    data['digit'].blank?
  end
end
