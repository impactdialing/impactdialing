module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    
    def publish_voter_connected
      redis_call_attempt = RedisCallAttempt.read(self.id)
      caller_session_id = redis_call_attempt['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session_id.nil?
        EM.run {
          if caller_session['type'] == 'WebuiCallerSession'
            event_hash = campaign.voter_connected_event(self.call)        
            caller_deferrable = Pusher[caller_session["session_key"]].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| }
          end
        }             
      end      
    end    
    
    def publish_voter_disconnected
      redis_call_attempt = RedisCallAttempt.read(self.id)
      caller_session_id = redis_call_attempt['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session_id.nil?
        EM.run {
          if caller_session['type'] == 'WebuiCallerSession'
            caller_deferrable = Pusher[caller_session["session_key"]].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| puts error.inspect}
          end
        }   
      end

    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end