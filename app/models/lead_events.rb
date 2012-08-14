module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      caller_session_id = RedisVoter.read(voter.id)['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session_id.nil?
        EM.run {
          if caller_session['caller_type'] == CallerSession::CallerType::TWILIO_CLIENT
            event_hash = campaign.voter_connected_event(self.call)        
            caller_deferrable = Pusher[caller_session["session_key"]].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| }
          end
           }
      end
    end    
    
    def publish_voter_disconnected
      caller_session_id = RedisVoter.read(voter.id)['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session_id.nil?
        EM.run {
          if caller_session['caller_type'] == CallerSession::CallerType::TWILIO_CLIENT
            caller_deferrable = Pusher[caller_session["session_key"]].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| puts error.inspect}
          end
        }   
      end
    end
    
    def publish_moderator_response_submited
      # unless caller_session.nil?
      #   EM.run {
      #     Moderator.active_moderators(campaign).each do |moderator|
      #       moderator_deferrable = Pusher[moderator.session].trigger_async('voter_event', {caller_session_id:  caller_session.id, campaign_id:  campaign.id, caller_id:  caller_session.caller.id, call_status: caller_session.attempt_in_progress.try(:status)})      
      #       moderator_deferrable.callback {}
      #       moderator_deferrable.errback { |error| }          
      #     end              
      #   }   
      # end      
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end