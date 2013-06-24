module SidekiqEvents
  module ClassMethods

  end

  module InstanceMethods

    def enqueue_call_flow(job, event_args)
      enqueue('call_flow', job, event_args)
    end


    def enqueue_monitor_caller_flow(job, event_args)
      enqueue('monitor_caller_update', job, event_args)
    end

    def enqueue_monitor_campaign_flow(job, event_args)
      enqueue('monitor_campaign_update', job, event_args)
    end


    def enqueue_call_end_flow(job, event_args)
      enqueue('call_end', job, event_args)
    end

    def enqueue(queue, job, event_args)
      Sidekiq::Client.push('queue' => queue, 'class' => job, 'args' => event_args)
    end

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end

