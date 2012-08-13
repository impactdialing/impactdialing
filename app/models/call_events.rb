class CallEvents
  
  def self.publish_voter_disconnected(caller_session_key)
    caller_deferrable = Pusher[caller_session_key].trigger_async("voter_disconnected", {})
    caller_deferrable.callback {}
    caller_deferrable.errback { |error| puts error.inspect}
    
  end
end
  