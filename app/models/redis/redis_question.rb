class RedisQuestion
  
  def self.persist_questions(script_id, question_id, question_text)
    $redis_call_flow_connection.lpush "question_list:script:#{script_id}", {id: question_id, question_text: question_text}.to_json
  end
  
  def self.get_question_to_read(script_id, question_number)
    question = $redis_call_flow_connection.lindex "question_list:script:#{script_id}", question_number 
    unless question.nil?
      JSON.parse(question)
    end
  end
  
  def self.more_questions_to_be_answered?(script_id, question_number)
    $redis_call_flow_connection.llen "question_list:script:#{script_id}" == (question_number - 1 )
  end
  
  
end