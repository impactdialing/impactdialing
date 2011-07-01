require File.join(RAILS_ROOT, 'config/environment')

module Dialer
  include ActionController::UrlWriter

  class << self
    def dial
      Twilio.default_options[:ssl_ca_file] = File.join(RAILS_ROOT, 'cacert.pem')
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      callback_url = "http://4bbe.localtunnel.com/twilio_callback"
      puts Twilio::Call.make('+14155130242', '+14155130242', "#{callback_url}?url=true", 'Timeout' => '20', 'FallbackUrl' => "#{callback_url}?fallback=1", 'StatusCallback' => "#{callback_url}?status_callback=1")
    end
  end
end

Dialer.dial
