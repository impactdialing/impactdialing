require Rails.root.join("lib/redis_connection")
class RedisCallerSession
  include Redis::Objects
  
  def self.load_caller_session_info(caller_session_id, caller_session, redis_connection)    
    caller_session(caller_session_id, redis_connection).bulk_set(caller_session.attributes)
  end
  
  def self.read(caller_session_id, redis_connection)
    caller_session(caller_session_id, redis_connection).all    
  end
  
  def is_on_call?
  end
  
  def self.caller_session(caller_session_id, redis_connection)
    Redis::HashKey.new("caller_session:#{caller_session_id}", redis_connection)    
  end
  
  def self.start_conference(caller_session_id, redis_connection)
    caller_session(caller_session_id, redis_connection).bulk_set({on_call: true, available_for_call: true})
    caller_session(caller_session_id, redis_connection).delete('attempt_in_progress')
  end
  
  def self.set_attempt_in_progress(caller_session_id, attempt_id, redis_connection)
    caller_session(caller_session_id, redis_connection).store("attempt_in_progress", attempt_id)
  end
  
  def self.set_voter_in_progress(caller_session_id, voter_id, redis_connection)
    caller_session(caller_session_id, redis_connection).store("voter_in_progress", voter_id)
  end
  
    
  def self.end_session(caller_session_id, redis_connection)
    caller_session(caller_session_id, redis_connection).store("end_time", Time.now)
    # update_attributes(on_call: false, available_for_call:  false, endtime:  Time.now)       
  end
  
  def self.disconnected?(caller_session_id, redis_connection)
    caller_session = read(caller_session_id, redis_connection)
    caller_session['on_call'] == "false" && caller_session["available_for_call"] == "false"
  end    
  
end