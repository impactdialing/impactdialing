module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected            
      unless caller_session.nil?
        EM.run {
          if !caller.is_phones_only? && !caller_session.nil?
            event_hash = campaign.voter_connected_event(self.call)        
            caller_deferrable = Pusher[caller_session.session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
            caller_deferrable.callback {EM.stop}
            caller_deferrable.errback { |error| EM.stop }
          end
          }
      end
      Resque.enqueue(ModeratorCallJob, self.id, "publish_voter_connected_moderator")
    end    
    
    def publish_voter_connected_moderator
      EM.run {
        Moderator.active_moderators(campaign).each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {EM.stop}
          moderator_deferrable.errback { |error| EM.stop }          
        end              
      }
      
    end
    
    def publish_voter_disconnected

      unless caller_session.nil?
        EM.run {
          now = Time.now
          unless caller_session.caller.is_phones_only?      
            caller_deferrable = Pusher[caller_session.session_key].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {EM.stop}
            caller_deferrable.errback { |error| EM.stop}
          end
          diff = (Time.now - now)* 1000
          puts "Voter DisConnected - #{diff}"
          
        }   
      end
      Resque.enqueue(ModeratorCallJob, self.id, "publish_voter_disconected_moderator")
      
    end
    
    def publish_voter_disconected_moderator
      EM.run {
        Moderator.active_moderators(campaign).each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {EM.stop}
          moderator_deferrable.errback { |error|  EM.stop}          
        end              
      }
    end
    
    def publish_moderator_response_submited

      unless caller_session.nil?
        EM.run {
                now = Time.now
          Moderator.active_moderators(campaign).each do |moderator|
            moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
            moderator_deferrable.callback {}
            moderator_deferrable.errback { |error| }          
          end              
          diff = (Time.now - now)* 1000
          puts "Voter Response Submitted - #{diff}"    
          
        }   
      end      
    end
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end