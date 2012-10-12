class LoadQuestionsAndPossibleResponses
  
  def perform
    Script.all.each do |script|
      RedisQuestion.clear_list(script.id)
      script.questions.each do|question|        
        RedisQuestion.persist_questions(script.id, question.id, question.text)
        RedisPossibleResponse.clear_list(question.id)
        question.possible_responses.each do |possible_response|          
          RedisPossibleResponse.persist_possible_response(question.id, possible_response.keypad, possible_response.value)
        end
      end
    end
  end
end