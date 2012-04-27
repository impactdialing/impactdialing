module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      event_hash = campaign.voter_connected_event(self)
      caller_session.publish_async(event_hash[:event], event_hash[:data])
    end    
    
    def publish_voter_disconnected
      caller_session.publish_async('voter_disconnected',{})
    end
      
    
    def publish_call_answered_by_machine
      event_hash = campaign.call_answered_machine_event(call_attempt)
      caller_session.publish(event_hash[:event], event_hash[:data]) if caller_session
    end
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end