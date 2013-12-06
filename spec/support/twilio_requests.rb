module TwilioRequests
  include RequestHelpers

  def twilio_credentials
    "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@"
  end
  def twilio_root_url
    "#{twilio_credentials}api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}"
  end
  def twilio_call_url(sid)
    "#{twilio_calls_url}/#{sid}"
  end
  def twilio_calls_url
    "#{twilio_root_url}/Calls"
  end
  def twilio_conferences_url
    "#{twilio_root_url}/Conferences"
  end
  def twilio_conference_by_name_url(name)
    "#{twilio_conferences_url}?FriendlyName=#{encode_uri(name)}"
  end
  def twilio_conference_kick_participant_url(conference_sid, call_sid)
    "#{twilio_conferences_url}/#{conference_sid}/Participants/#{call_sid}"
  end
  def request_body(url)
    "CurrentUrl=#{encode_uri(url)}&CurrentMethod=POST"
  end
end
