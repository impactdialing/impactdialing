class RedisPossibleResponse
  
  def self.persist_possible_response(question_id, keypad, value)
    $redis_call_flow_connection.lpush "possible_response:#{question_id}", {id: question_id, keypad: keypad, value: value}.to_json
  end
  
  def self.possible_responses(question_id)
    possible_responses = $redis_call_flow_connection.lrange "possible_response:#{question_id}", 0, -1
    unless possible_responses.blank?
      possible_responses.collect {|x| JSON.parse(x)}      
    end
  end
  
end