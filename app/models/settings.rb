# class Settings < Settingslogic
#   source "#{Rails.root}/config/application.yml"
#   namespace Rails.env
# end

class Settings
  def self.current_class
    class << self; self; end
  end


  current_class.instance_eval do
    [
      'twilio_callback_host', 'call_end_callback_host',
      'incoming_callback_host', 'voip_api_url',
      'twilio_callback_port', 'recording_env',
      'callin_phone'
    ].each do |str|
      define_method(str) do
        ENV[str.upcase]
      end
    end
  end
end