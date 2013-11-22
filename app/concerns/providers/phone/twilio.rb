module Providers::Phone::Twilio
  def self.connect
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  end

  def self.redirect(call_sid, url)
    connect
    xml = Twilio::Call.redirect(call_sid, url)
    return Response.new(xml)
  end

  def self.make(from, to, url, params)
    connect
    xml = Twilio::Call.make(from, to, url, params)
    return Response.new(xml)
  end
end