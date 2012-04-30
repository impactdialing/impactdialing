module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      event_hash = campaign.voter_connected_event(self.call)
      caller_session.publish_async(event_hash[:event], event_hash[:data])
    end    
    
    def publish_voter_disconnected
      caller_session.publish_async('voter_disconnected',{})
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end