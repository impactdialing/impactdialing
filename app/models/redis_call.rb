require 'redis/list'
class RedisCall
  include Redis::Objects
  
  
  def self.store_not_answered_call_list(call_params)
    not_answered_call_list << call_params
  end
  
  def self.store_abandoned_call_list(call_params)
    abandoned_call_list << call_params
  end
  
  def self.store_answered_by_machine_call_list(call_params)
    answered_by_machine_call_list << call_params
  end
  
  def self.store_answered_call_list(call_params)
    answered_call_list << call_params
  end
  
  def self.store_wrapped_up_call_list(call_params)
    wrapped_up_call_list << call_params
  end
  
  def self.not_answered_call_list
    Redis::List.new("not_answered_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.abandoned_call_list
    Redis::List.new("abandoned_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.answered_by_machine_call_list
    Redis::List.new("answered_by_machine_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.answered_call_list
    Redis::List.new("answered_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  def self.wrapped_up_call_list
    Redis::List.new("wrapped_up_call_list", $redis_call_flow_connection,:marshal => true)        
  end
  
  
  
  
  
end