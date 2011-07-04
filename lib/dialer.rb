require File.join(RAILS_ROOT, 'config/environment')

module Dialer
  include ActionController::UrlWriter

  class << self
    def dial
      Twilio.default_options[:ssl_ca_file] = File.join(RAILS_ROOT, 'cacert.pem')
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      callback_url = "http://3vhu.localtunnel.com/twilio_callback"
      fallback_url = "http://3vhu.localtunnel.com/twilio_report_error"
      callended_url = "http://3vhu.localtunnel.com/twilio_call_ended"
      puts Twilio::Call.make('+14155130242', '+14155130242', callback_url, 'Timeout' => '20', 'FallbackUrl' => fallback_url, 'StatusCallback' => callended_url)
    end
  end
end

Dialer.dial
