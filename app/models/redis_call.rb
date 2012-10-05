class RedisCall
  
  def self.store_call_details(params)
    Sidekiq::Client.push('queue' => "call_end", 'class' => CallEndJob, 'args' => [params])
  end
end