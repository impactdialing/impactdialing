class RedisCall
  
  def self.store_call_details(params)
    Resque.enqueue(CallEndJob, params);    
  end
end