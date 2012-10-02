module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def enqueue_call_flow(job, args)
      Sidekiq::Client.push('queue' => 'call_flow', 'class' => job, 'args' => args)
    end
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end  

