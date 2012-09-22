module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected            
      unless caller_session.nil?
        if !caller_session.caller.is_phones_only? 
        EM.run {          
            event_hash = campaign.voter_connected_event(self.call)        
            caller_deferrable = Pusher[caller_session.session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
            caller_deferrable.callback {EM.stop}
            caller_deferrable.errback { |error| EM.stop }
          
          }
        end
      end
    end    
    
    
    def publish_voter_disconnected

      unless caller_session.nil?
        unless caller_session.caller.is_phones_only?      
        EM.run {
          
            caller_deferrable = Pusher[caller_session.session_key].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {EM.stop}
            caller_deferrable.errback { |error| EM.stop}
          
        }   
      end  
      end
      
    end
    
    def publish_voter_connected_moderator
      unless Moderator.active_moderators(campaign).size == 0
        EM.run {
          Moderator.active_moderators(campaign).each do |moderator|
            moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
            moderator_deferrable.callback {EM.stop}
            moderator_deferrable.errback { |error| EM.stop }          
          end              
        }
      end
      
    end
    
    
    def publish_voter_disconected_moderator
      unless Moderator.active_moderators(campaign).size == 0
        EM.run {
          Moderator.active_moderators(campaign).each do |moderator|
            moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
            moderator_deferrable.callback {EM.stop}
            moderator_deferrable.errback { |error|  EM.stop}          
          end              
        }
      end
    end
    
    def publish_moderator_response_submited
      unless Moderator.active_moderators(campaign).size == 0
        unless caller_session.nil?
          EM.run {
            Moderator.active_moderators(campaign).each do |moderator|
              moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
              moderator_deferrable.callback {EM.stop}
              moderator_deferrable.errback { |error| EM.stop }          
            end              
          }   
        end
      end      
    end
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end