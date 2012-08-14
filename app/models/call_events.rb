class CallEvents
  
  def self.publish_voter_connected(caller_session_key, call, campaign)
    EM.run {
      event_hash = campaign.voter_connected_event(call)        
      caller_deferrable = Pusher[caller_session_key].trigger_async(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
      caller_deferrable.callback {}
      caller_deferrable.errback { |error| }
    }
  end
  
  def self.publish_voter_disconnected(caller_session_key)
    EM.run {
      caller_deferrable = Pusher[caller_session_key].trigger_async("voter_disconnected", {})
      caller_deferrable.callback {}
      caller_deferrable.errback { |error| puts error.inspect}    
    }
  end
  
  
end
  