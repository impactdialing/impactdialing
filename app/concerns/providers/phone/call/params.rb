module Providers::Phone::Call::Params
  def self.for(obj, type=:default)
    params = self.const_get("#{obj.class}").new(obj, type)
    return params
  end

  def self.default_url_options
    return {
      :host => Settings.twilio_callback_host,
      :port => Settings.twilio_callback_port,
      :protocol => "http://"
    }
  end
end