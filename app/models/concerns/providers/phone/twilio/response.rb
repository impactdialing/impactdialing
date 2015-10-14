##
# Provides a thin wrapper around Twilio REST responses to provide
# a central location for rescuing exceptions raised during REST request.
#
# twilio-ruby will raise one of Twilio::REST::RequestError or
# Twilio::REST::ServerError when a REST request fails.
#
# This class will rescue & log these errors then set @error to true.
class Providers::Phone::Twilio::Response
  attr_reader :resource

public
  def initialize(&block)
    @error = false

    begin
      @resource = yield if block_given?
    rescue Twilio::REST::RequestError, Twilio::REST::ServerError => e
      @resource = nil
      @error    = true
      TwilioLogger.log("Code[#{e.code}] Message[#{e.message}]")
    end
  end

  def success?
    not error?
  end

  def error?
    @error
  end
end
