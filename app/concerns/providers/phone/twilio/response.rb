class Providers::Phone::Twilio::Response
  class InvalidContent < ArgumentError; end

  attr_reader :content

private
  def validate_content!(content)
    if content['TwilioResponse'].nil?
      raise InvalidContent, 'Content must have a TwilioResponse key'
    end
  end

public
  def initialize(content)
    validate_content!(content)
    @content = content['TwilioResponse']
  end

  def success?
    content['RestException'].nil?
  end

  def error?
    not success?
  end

  def call_sid
    content['Call']['Sid']
  end

  def [](key)
    content[key]
  end
end