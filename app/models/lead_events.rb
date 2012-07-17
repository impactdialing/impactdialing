module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected      
      unless caller_session.nil?
        EM.run {
          unless caller_session.caller.is_phones_only?
            event_hash = campaign.voter_connected_event(self.call)        
            caller_deferrable = Pusher[caller_session.session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| }
          end
        }      
      end
      ModeratorEvent.voter_connected(campaign, caller_session)
      
    end    
    
    def publish_voter_disconnected
      unless caller_session.nil?
        EM.run {
          unless caller_session.caller.is_phones_only?      
            caller_deferrable = Pusher[caller_session.session_key].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| puts error.inspect}
          end          
        }   
      end
      ModeratorEvent.voter_disconnected(campaign, caller_session)
    end
    
    def publish_moderator_response_submited
      ModeratorEvent.voter_response_submitted(campaign, caller_session)
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end