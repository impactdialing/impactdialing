module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      unless caller_session.caller.is_phones_only?
        event_hash = campaign.voter_connected_event(self.call)
        caller_session.publish_async(event_hash[:event], event_hash[:data])
      end
    end    
    
    def publish_voter_disconnected
      unless caller_session.caller.is_phones_only?
        caller_session.publish_async('voter_disconnected',{})
      end
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end