module Providers::Phone::Call::Params
  def self.for(obj, type=:default)
    params = self.const_get("#{obj.class}").new(obj, type)
    return params
  end

  def self.default_url_options
    return {
      :host => DataCentre.call_back_host(nil),
      :port => Settings.twilio_callback_port,
      :protocol => "http://"
    }
  end
end