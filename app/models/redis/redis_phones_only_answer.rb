class RedisPhonesOnlyAnswer
  
  def self.push_to_list(voter_id, caller_session_id, digit, question_id)
    $redis_phones_ans_uri_connection.lpush "phones_only_answer_list", {voter_id: voter_id, caller_session_id: caller_session_id, question_id: question_id, digit: digit}.to_json
  end
  
  def self.phones_only_answers_list
    $redis_phones_ans_uri_connection.lrange "phones_only_answer_list", 0, -1       
  end
end