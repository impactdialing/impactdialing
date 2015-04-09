module Providers::Phone::Call::Params
  def self.for(obj, type=:default)
    klass = obj.class.to_s
    if ['WebuiCallerSession', 'PhonesOnlyCallerSession'].include? klass
      # todo: move these to configuration obj
      klass = 'CallerSession'
    end
    klass = [self.to_s, klass].join('::')
    return klass.constantize.new(obj, type)
  end

  def self.default_url_options
    return {
      :host => Settings.twilio_callback_host,
      :port => Settings.twilio_callback_port,
      :protocol => "http://"
    }
  end
end