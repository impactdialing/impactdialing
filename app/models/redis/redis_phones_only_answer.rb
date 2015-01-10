class RedisPhonesOnlyAnswer
  def self.keys
    {
      master: 'phones_only_answer_list',
      pending: 'phones_only_answer_list:pending',
      partial: 'phones_only_answer_list:partial'
    }
  end

  def self.push_to_list(voter_id, household_id, caller_session_id, digit, question_id)
    $redis_phones_ans_uri_connection.lpush keys[:master], {
      voter_id:          voter_id,
      household_id:      household_id,
      caller_session_id: caller_session_id,
      question_id:       question_id,
      digit:             digit
    }.to_json
  end
  
  def self.phones_only_answers_list
    $redis_phones_ans_uri_connection.lrange keys[:master], 0, -1       
  end
end