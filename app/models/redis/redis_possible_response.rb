class RedisPossibleResponse
  
  def self.persist_possible_response(question_id, keypad, value)
    $redis_question_pr_uri_connection.lpush "possible_response:#{question_id}", {id: question_id, keypad: keypad, value: value}.to_json
  end
  
  def self.possible_responses(question_id)
    possible_responses = $redis_question_pr_uri_connection.lrange "possible_response:#{question_id}", 0, -1
    unless possible_responses.blank?
      possible_responses.collect {|x| JSON.parse(x)}      
    end
  end
  
  def self.clear_list(question_id)
    $redis_question_pr_uri_connection.del("possible_response:#{question_id}")
  end
  
end