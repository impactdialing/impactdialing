require 'redis/list'
class RedisCall
  include Redis::Objects
  
  # done
  def self.push_to_not_answered_call_list(call_params)    
    not_answered_call_list << call_params.merge("current_time"=> Time.now.to_s)
  end
  
  # done
  def self.push_to_abandoned_call_list(call_params)    
    p call_params
    abandoned_call_list << call_params.merge("current_time"=> Time.now.to_s)
  end
  
  # done
  def self.push_to_processing_by_machine_call_hash(call_params)    
    processing_by_machine_call_hash.store(call_params['id'], Time.now.to_s) 
  end
  
  # done
  def self.push_to_end_by_machine_call_list(call_params)    
    end_answered_by_machine_call_list << call_params.merge("current_time"=> Time.now.to_s)
  end
  
    
  def self.push_to_disconnected_call_list(call_params)    
    disconnected_call_list << call_params.merge("current_time"=> Time.now.to_s)
  end
  
  def self.push_to_wrapped_up_call_list(call_attempt_params)    
    wrapped_up_call_list << call_attempt_params.merge("current_time"=> Time.now.to_s)
  end
  
  def self.not_answered_call_list
    Redis::List.new("not_answered_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  
  def self.abandoned_call_list
    Redis::List.new("abandoned_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.processing_by_machine_call_hash
    Redis::HashKey.new("processing_by_machine_call_list", $redis_call_flow_connection)        
  end
  
  def self.end_answered_by_machine_call_list
    Redis::List.new("end_answered_by_machine_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.disconnected_call_list
    Redis::List.new("disconnected_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.wrapped_up_call_list
    Redis::List.new("wrapped_up_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  
  
  
  
end
