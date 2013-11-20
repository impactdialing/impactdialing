module Providers::Phone::Call
  def self.connect
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  end

  def self.redirect(call_sid, url)
    connect
    RescueRetryNotify.on(SocketError, 5) do
      Twilio::Call.redirect(call_sid, url)
    end
  end
end
