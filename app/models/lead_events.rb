module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_incoming_call
      MonitorEvent.incoming_call_request(campaign)
    end
    
    def publish_voter_connected
      redis_voter = RedisVoter.read(voter.id)
      caller_session_id = redis_voter['caller_session_id']
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
      MonitorEvent.create_caller_notification(campaign.id, caller_session_id, redis_voter["status"])  
      end
      MonitorEvent.voter_connected(campaign)      
    end    
    
    def publish_voter_disconnected
      redis_voter = RedisVoter.read(voter.id)
      caller_session_id = redis_voter['caller_session_id']
      caller_session = RedisCallerSession.read(caller_session_id)      
      unless caller_session_id.nil?
        EM.run {
          if caller_session['type'] == 'WebuiCallerSession'
            caller_deferrable = Pusher[caller_session["session_key"]].trigger_async("voter_disconnected", {})
            caller_deferrable.callback {}
            caller_deferrable.errback { |error| puts error.inspect}
          end
        }   
      MonitorEvent.create_caller_notification(campaign.id, caller_session_id, redis_voter["status"])  
      end
      MonitorEvent.voter_disconnected(campaign)
    end
    
    def publish_moderator_response_submited
      MonitorEvent.voter_response_submitted(campaign)
      caller_session_id = RedisVoter.read(voter.id)['caller_session_id']
      MonitorEvent.create_caller_notification(campaign.id, caller_session_id, "On hold")  
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end