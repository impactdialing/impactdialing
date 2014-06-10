##
# This provides a thin convenience wrapper to Twilio
# responses returned from the Twilio gem by webficient:
# https://github.com/webficient/twilio.
#
# The Twilio gem returns a HTTParty::Response instance
# from requests:
# https://github.com/jnunemaker/httparty/blob/master/lib/httparty/response.rb
#
class Providers::Phone::Twilio::Response
  attr_reader :content, :response

public
  def initialize(response)
    @response = response
    if response.parsed_response.nil?
      @content = response.parsed_response
    else
      @content = response.parsed_response['TwilioResponse']
    end

    if error?
      TwilioLogger.error(content)
    end
  end

  def success?
    (200 <= status &&
         status < 400) ||
    (content.kind_of?(Hash) &&
     content['RestException'].nil?)
  end

  def error?
    not success?
  end

  def status
    response.code.to_i
  end

  def call_sid
    content['Call']['Sid']
  end

  def conference
    content['Conferences']['Conference']
  end

  def conference_sid
    return nil if conference.nil?
    conference.class == Array ? conference.last['Sid'] : conference['Sid']
  end
end