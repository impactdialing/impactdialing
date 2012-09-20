class RedisCallerSession
  include Redis::Objects
  
  def self.load_caller_session_info(caller_session_id, caller_session)    
    caller_session(caller_session_id).bulk_set(caller_session.attributes)
  end
  
  def self.read(caller_session_id)
    caller_session(caller_session_id).all    
  end
    
  def self.caller_session(caller_session_id)
    Redis::HashKey.new("caller_session:#{caller_session_id}", $redis_call_flow_connection)    
  end
  
  def self.start_conference(caller_session_id)
    caller_session(caller_session_id).delete('attempt_in_progress')
  end
  
  def self.set_attempt_in_progress(caller_session_id, attempt_id)
    caller_session(caller_session_id).store("attempt_in_progress", attempt_id)
  end
  
  def self.attempt_in_progress(caller_session_id)
    caller_session(caller_session_id).fetch("attempt_in_progress")
  end
  
  
  def self.set_voter_in_progress(caller_session_id, voter_id)
    caller_session(caller_session_id).store("voter_in_progress", voter_id)
  end
  
  def self.voter_in_progress?(caller_session_id)
    caller_session(caller_session_id).has_key?("voter_in_progress")
  end
  
  def self.voter_in_progress(caller_session_id)
    caller_session(caller_session_id).fetch("voter_in_progress")
  end
  
    
  def self.end_session(caller_session_id)
    caller_session(caller_session_id).bulk_set({on_call: false, available_for_call: false, end_time: Time.now})
    caller_session(caller_session_id).delete('voter_in_progress')
  end
  
  def self.disconnected?(caller_session_id)
    caller_session = read(caller_session_id)
    caller_session['on_call'] == "false" && caller_session["available_for_call"] == "false"
  end    
  
end