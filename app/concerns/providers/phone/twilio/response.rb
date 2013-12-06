class Providers::Phone::Twilio::Response
  class InvalidContent < ArgumentError; end

  attr_reader :content

private
  def validate_content!(content)
    if content['TwilioResponse'].nil? && content.size > 0
      raise InvalidContent, 'Content must have a TwilioResponse key'
    end
  end

public
  def initialize(content)
    validate_content!(content)
    if content.size > 0
      @content = content['TwilioResponse']
    else
      @content = content
    end
  end

  def success?
    200 <= status &&
    status < 400 &&
    content['RestException'].nil?
  end

  def error?
    not success?
  end

  def status
    (content['Status'] || content.code).to_i
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