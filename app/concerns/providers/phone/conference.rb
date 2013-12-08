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

  def self.call(method, *args)
    opts = args.pop
    retry_up_to = opts[:retry_up_to]
    response = nil
    RescueRetryNotify.on(SocketError, retry_up_to) do
      response = service.send(method, *args)
    end
    return response
  end

  def self.list(search_options={}, opts={})
    return call(:conference_list, search_options, opts)
  end

  def self.kick(caller_session, opts={})
    conference_sid  = sid_for(caller_session.session_key)
    call_sid        = caller_session.sid
    return call(:kick, conference_sid, call_sid, opts)
  end
end
