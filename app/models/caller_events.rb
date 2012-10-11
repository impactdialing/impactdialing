module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def publish_start_calling
      if state == "initial"
        publish_sync('start_calling', {caller_session_id: id})
      end
    end    
    
    def publish_voter_connected(call_id)            
      call = Call.find(call_id)
      event_hash = campaign.voter_connected_event(call)
      Pusher[session_key].trigger!(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
    end    
    
    
    def publish_voter_disconnected
      unless caller.is_phones_only?      
        Pusher[session_key].trigger!("voter_disconnected", {})
      end  
    end
        
    def publish_caller_conference_started
      unless caller.is_phones_only? 
        event_hash = campaign.caller_conference_started_event(voter_in_progress.try(:id))     
        Pusher[session_key].trigger!(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
     end      
    end
    
    def publish_calling_voter
      Pusher[session_key].trigger!('calling_voter', {}) unless caller.is_phones_only? 
    end
        
    def publish_caller_disconnected      
      Pusher[session_key].trigger!("caller_disconnected", {}) unless caller.is_phones_only?
    end   
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end
