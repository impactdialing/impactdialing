module Providers::Phone::Call
  def self.service
    Providers::Phone::Twilio
  end

  def self.redirect(call_sid, url, opts={})
    retry_up_to = opts[:retry_up_to]
    RescueRetryNotify.on(SocketError, retry_up_to) do
      service.redirect(call_sid, url)
    end
  end

  def self.redirect_for(obj, type=:default)
    params = Params.for(obj, type)
    redirect(params.call_sid, params.url, {retry_up_to: 5})
  end

  def self.make(from, to, url, params, opts={})
    retry_up_to = opts[:retry_up_to]
    RescueRetryNotify.on(SocketError, retry_up_to) do
      service.make(from, to, url, params)
    end
  end

  def self.make_for(obj, type=:default)
    params = Params.for(obj, type)
    make(params.from, params.to, params.url, params.params, {retry_up_to: 5})
  end
end
