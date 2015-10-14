module Providers::Phone::Twilio
  def self.connect(&block)
    client   = Twilio::REST::Client.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    return Response.new{ block.call(client) }
  end

  def self.redirect(call_sid, url)
    connect do |client|
      call = client.calls.get(call_sid)
      call.redirect_to(url)
    end
  end

  def self.make(from, to, url, params)
    connect do |client|
      client.calls.create(params.merge({
        from: from,
        to: to,
        url: url
      }))
    end
  end

  def self.conference_list(search_options={})
    connect do |client|
      client.conferences.list(search_options)
    end
  end

  def self.kick(conference_sid, call_sid)
    connect do |client|
      participant = client.conferences.get(conference_sid).participants.get(call_sid)
      participant.kick
    end
  end

  def self.mute_participant(conference_sid, call_sid)
    connect do |client|
      participant = client.conferences.get(conference_sid).participants.get(call_sid)
      participant.mute
    end
  end

  def self.unmute_participant(conference_sid, call_sid)
    connect do |client|
      participant = client.conferences.get(conference_sid).participants.get(call_sid)
      participant.unmute
    end
  end
end

