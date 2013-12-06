module Providers::Phone::Conference
  def self.service
    Providers::Phone::Twilio
  end

  def self.by_name(name, opts={})
    opts[:retry_up_to] ||= 5
    response = list({'FriendlyName' => name}, opts)
    return response
  end

  def self.sid_for(name, opts={})
    opts[:retry_up_to] ||= 5
    response = by_name(name, opts)
    return response.conference_sid
  end

  def self.list(search_options={}, opts={})
    retry_up_to = opts[:retry_up_to]
    response    = nil
    RescueRetryNotify.on(SocketError, retry_up_to) do
      response = service.conference_list(search_options)
    end
    return response
  end

  def self.kick(caller_session, opts={})
    retry_up_to     = opts[:retry_up_to]
    conference_sid  = sid_for(caller_session.session_key)
    call_sid        = caller_session.sid
    response        = nil
    RescueRetryNotify.on(SocketError, retry_up_to) do
      response = service.kick(conference_sid, caller_session.sid)
    end
    return response
  end
end
