module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      
      EM.run {
        unless caller_session.caller.is_phones_only?
          event_hash = campaign.voter_connected_event(self.call)        
          caller_deferrable = Pusher[caller_session.session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
          caller_deferrable.callback {}
          caller_deferrable.errback { |error| }
        end
        campaign.account.moderators.last_hour.active.each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {}
          moderator_deferrable.errback { |error| }          
        end              
         }
    end    
    
    def publish_voter_disconnected
      EM.run {
        unless caller_session.caller.is_phones_only?      
          caller_deferrable = Pusher[caller_session.session_key].trigger_async("voter_disconnected", {})
          caller_deferrable.callback {}
          caller_deferrable.errback { |error| }
        end
        campaign.account.moderators.last_hour.active.each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {}
          moderator_deferrable.errback { |error| }          
        end              
      }   
    end
    
    def publish_moderator_response_submited
      EM.run {
        campaign.account.moderators.last_hour.active.each do |moderator|
          moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
          moderator_deferrable.callback {}
          moderator_deferrable.errback { |error| }          
        end              
      }   
      
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end