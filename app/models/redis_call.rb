class RedisCall
  include SidekiqEvents
  
  def self.store_call_details(params)
    enqueue_call_end_flow(CallEndJob, [params: params])
  end
end