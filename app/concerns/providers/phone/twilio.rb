module Providers::Phone::Twilio
  def self.connect
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  end

  def self.redirect(call_sid, url)
    connect
    Twilio::Call.redirect(call_sid, url)
  end
end