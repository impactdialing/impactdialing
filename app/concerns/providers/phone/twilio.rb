module Providers::Phone::Twilio
  def self.connect(&block)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    xml = yield
    return Response.new(xml)
  end

  def self.redirect(call_sid, url)
    connect{ Twilio::Call.redirect(call_sid, url) }
  end

  def self.make(from, to, url, params)
    connect{ Twilio::Call.make(from, to, url, params) }
  end

  def self.conference_list(search_options={})
    connect{ Twilio::Conference.list(search_options) }
  end

  def self.kick(conference_sid, call_sid)
    connect{ Twilio::Conference.kick_participant(conference_sid, call_sid) }
  end
end
