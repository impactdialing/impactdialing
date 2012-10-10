require 'redis/list'
class RedisCall
  include Redis::Objects
  
  # done
  def self.push_to_not_answered_call_list(call_id, call_status)   
    $redis_call_end_connection.lpush "not_answered_call_list", {id: call_id, call_status: call_status, current_time: Time.now.to_s}.to_json
  end
  
  # done
  def self.push_to_abandoned_call_list(call_id)    
    $redis_call_flow_connection.lpush "abandoned_call_list", {id: call_id, current_time: Time.now.to_s}.to_json
  end
  
  # done
  def self.push_to_processing_by_machine_call_hash(call_id)        
    processing_by_machine_call_hash.store(call_id, Time.now.to_s) 
  end
  
  # done
  def self.push_to_end_by_machine_call_list(call_id)    
    $redis_call_flow_connection.lpush "end_answered_by_machine_call_list", {id: call_id, current_time: Time.now.to_s}.to_json
  end
  
    
  def self.push_to_disconnected_call_list(call_id, recording_duration, recording_url, caller_id)    
    $redis_call_flow_connection.lpush "disconnected_call_list", {id: call_id, recording_duration: recording_duration, recording_url: recording_url, caller_id: caller_id, current_time: Time.now.to_s}.to_json
  end
  
  def self.push_to_wrapped_up_call_list(call_id, caller_type)    
    $redis_call_flow_connection.lpush "wrapped_up_call_list", {id: call_id, caller_type: caller_type, current_time: Time.now.to_s}.to_json
  end
  
  def self.not_answered_call_list
    $redis_call_end_connection.lrange "not_answered_call_list", 0, -1
  end
  
  def self.abandoned_call_list
    $redis_call_flow_connection.lrange "abandoned_call_list", 0, -1       
  end
  
  def self.processing_by_machine_call_hash
    Redis::HashKey.new("processing_by_machine_call_list", $redis_call_flow_connection)        
  end
  
  def self.end_answered_by_machine_call_list
    $redis_call_flow_connection.lrange "end_answered_by_machine_call_list", 0, -1     
  end
  
  def self.disconnected_call_list
    $redis_call_flow_connection.lrange "disconnected_call_list", 0, -1
  end
  
  def self.wrapped_up_call_list
    $redis_call_flow_connection.lrange "wrapped_up_call_list", 0, -1
  end
  
  
  
  
  
end
