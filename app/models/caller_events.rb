module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def publish_start_calling
      publish_sync('start_calling', {caller_session_id: id}) if state == 'initial'                     
    end    
    
    def publish_caller_conference_started
      event_hash = campaign.caller_conference_started_event
      publish_async(event_hash[:event], event_hash[:data])                     
    end
    
    def publish_calling_voter
      publish_async('calling_voter', {})
    end
    
    def publish_caller_disconnected
      publish_async("caller_disconnected",{})    
    end    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end