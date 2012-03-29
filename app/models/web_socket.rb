class WebSocket
  
  
  def self.publish_for_caller(session_key, event, data, dialer_type, web_ui)
    return unless web_ui
    Pusher[session_key].trigger(event, data.merge!(:dialer => dialer_type))
  end
  
  def self.publish_for_moderator(session_key, event, data)
    Pusher[session_key].trigger(event, data)
  end
  
end