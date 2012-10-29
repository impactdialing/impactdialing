class RedisCallerSession
  
  def self.set_request_params(caller_session_id, options)
    $redis_caller_session_uri_connection.set "caller_session_flow:#{caller_session_id}", options.to_json
  end
  
  def self.delete(caller_session_id)
    $redis_caller_session_uri_connection.del "caller_session_flow:#{caller_session_id}"
  end
  
  
  def self.get_request_params(caller_session_id)
    $redis_caller_session_uri_connection.get "caller_session_flow:#{caller_session_id}"
  end
  
  
  def self.digit(caller_session_id)
    data = $redis_caller_session_uri_connection.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["digit"]
  end
  
  def self.question_id(caller_session_id)
    data = $redis_caller_session_uri_connection.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["question_id"]
  end

  def self.question_number(caller_session_id)
    data = $redis_caller_session_uri_connection.get "caller_session_flow:#{caller_session_id}"
    hash = JSON.parse(data)
    hash["question_number"]
  end
  
  def set_datacentre(caller_session_id, caller_dc)
    $redis_caller_session_uri_connection.set "caller_dc:#{caller_session_id}", caller_dc
  end
  
  def datacentre(caller_session_id)
    $redis_caller_session_uri_connection.get "caller_dc:#{caller_session_id}"
  end
  
  
end