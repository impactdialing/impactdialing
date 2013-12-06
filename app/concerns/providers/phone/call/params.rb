module Providers::Phone::Call::Params
  def self.for(obj, type=:default)
    klass = "#{obj.class}"
    if ['WebuiCallerSession', 'PhonesOnlyCallerSession'].include? klass
      # todo: move these to configuration obj
      klass = 'CallerSession'
    end
    params = self.const_get(klass).new(obj, type)
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