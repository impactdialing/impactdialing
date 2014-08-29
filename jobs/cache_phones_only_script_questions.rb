require 'resque-loner'

class CachePhonesOnlyScriptQuestions
  include Resque::Plugins::UniqueJob
  @queue = :persist_jobs

  def self.perform(script_id)
    script = Script.find script_id

    $redis_question_pr_uri_connection.multi do
      RedisQuestion.clear_list(script.id)

      script.questions.reverse.each do|question|
        RedisQuestion.persist_questions(script.id, question.id, question.text)

        RedisPossibleResponse.clear_list(question.id)
        
        question.possible_responses.reverse.each do |possible_response|
          RedisPossibleResponse.persist_possible_response(question.id, possible_response.keypad, possible_response.value)
        end
      end      
    end
  end
end
