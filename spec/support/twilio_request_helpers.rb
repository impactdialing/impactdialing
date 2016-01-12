module TwilioRequestHelpers
  include RequestHelpers

  def twilio_invalid_to
    '+15005550001'
  end
  def twilio_valid_from
    '15005550006'
  end
  def twilio_valid_to
    '15005550006'
  end
  def twilio_credentials
    "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@"
  end
  def twilio_root_url
    "#{twilio_credentials}api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}"
  end
  def twilio_call_url(sid)
    "#{twilio_calls_url.gsub('.json','')}/#{sid}.json"
  end
  def twilio_calls_url
    "#{twilio_root_url}/Calls.json"
  end
  def twilio_conferences_url
    "#{twilio_root_url}/Conferences.json"
  end
  def twilio_participants_url(conference_sid)
    "#{twilio_conference_url(conference_sid)}/Participants"
  end
  def twilio_participant_url(conference_sid, call_sid)
    "#{twilio_participants_url(conference_sid).gsub('.json','')}/#{call_sid}.json"
  end
  def twilio_conference_url(conference_sid)
    "#{twilio_conferences_url}/#{conference_sid}"
  end
  def twilio_conference_by_name_url(name)
    "#{twilio_conferences_url}?FriendlyName=#{encode_uri(name)}"
  end
  def twilio_conference_kick_participant_url(conference_sid, call_sid)
    twilio_participant_url(conference_sid, call_sid)
  end
  def twilio_conference_mute_url(conference_sid, call_sid)
    twilio_participant_url(conference_sid, call_sid)
  end
  def twilio_conference_unmute_url(conference_sid, call_sid)
    twilio_participant_url(conference_sid, call_sid)
  end
  def twilio_mute_request_body
    "Muted=true"
  end
  def twilio_unmute_request_body
    "Muted=false"
  end
  def request_body(url)
    uri = encode_uri(url)
    "Url=#{uri}&FallbackUrl=#{uri}"
  end
end
