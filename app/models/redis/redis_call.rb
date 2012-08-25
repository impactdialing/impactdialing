class RedisCall
  
  def self.call_completed(call_attempt_id, voter_id)
    $redis_call_flow_connection.rpush('call_completed', {call_attempt_id: call_attempt_id, voter_id: voter_id}.to_json)
  end
  
end