module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected            
      redis_call_attempt = RedisCallAttempt.read(self.id)
      caller_session_id = redis_call_attempt['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)            
      unless caller_session.nil?
        if caller_session['type'] == 'WebuiCallerSession' 
          event_hash = campaign.voter_connected_event(self.call)        
          Pusher[caller_session['session_key']].trigger!(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
        end
      end
    end    
    
    
    def publish_voter_disconnected
      redis_call_attempt = RedisCallAttempt.read(self.id)
      caller_session_id = redis_call_attempt['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session.nil?
        unless caller_session.caller.is_phones_only?      
          Pusher[caller_session['session_key']].trigger!("voter_disconnected", {})
        end  
      end      
    end
    
    def publish_voter_event_moderator
      unless caller_session.nil?
        Moderator.active_moderators(campaign).each do |moderator|
          Pusher[moderator.session].trigger!('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
        end              
      end
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end