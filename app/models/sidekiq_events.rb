module SidekiqEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def enqueue_call_flow(job, args)
      enqueue('call_flow', job, args)
    end
    
    def enqueue_moderator_flow(job, args)
      enqueue('moderator_flow', job, args)
    end
    
    def enqueue(queue, job, args)
      Sidekiq::Client.push('queue' => queue, 'class' => job, 'args' => args)
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end  

