module Providers::Phone::Twilio
  def self.retry_limit
    limit = ENV['TWILIO_RETRIES'].to_i 
    limit > 0 ? limit : 1
  end

  def self.connect(&block)
    client   = Twilio::REST::Client.new(TWILIO_ACCOUNT, TWILIO_AUTH, {
      ssl_ca_file: ENV['SSL_CERT_FILE'],
      retry_limit: retry_limit
    })
    return Response.new{ block.call(client) }
  end

  def self.redirect(call_sid, url)
    connect do |client|
      call = client.calls.get(call_sid)
      call.update({
        url: url,
        fallback_url: url
      })
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

